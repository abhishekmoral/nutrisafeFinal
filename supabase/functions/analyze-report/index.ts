// NutriSafe - medical report reader (Supabase Edge Function).
//
// Two steps, each started by the app:
//   action "extract": read the uploaded PDF / image and store the printed test results
//   action "explain": explain the (user-reviewed) results in simple language
//
// The model only reads and explains. Comparing values with the lab's range, flagging
// critical values and the urgent guidance text are done by the code in rules.ts.
// Secret needed: ANTHROPIC_API_KEY. All database access uses the caller's JWT (RLS applies).

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";
import { encodeBase64 } from "jsr:@std/encoding@1/base64";
import { flagFor, parseNumeric, urgentGuidance, validateResult } from "./rules.ts";

const MODEL = "claude-opus-5-5";
const BUCKET = "medical-reports";
const MAX_FILE_BYTES = 10 * 1024 * 1024;
// Photos are sent base64-encoded and must stay under the AI service's 5 MB image limit.
const MAX_IMAGE_BYTES = Math.floor(3.7 * 1024 * 1024);
const MAX_RESULTS = 300;
const MAX_REQUESTS_PER_HOUR = 12;
const AI_TIMEOUT_MS = 120_000;

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English", hi: "Hindi", hinglish: "Hinglish (Hindi written in Latin script, mixed with English)",
  bn: "Bengali", ta: "Tamil", te: "Telugu", mr: "Marathi", gu: "Gujarati", pa: "Punjabi",
  ur: "Urdu", kn: "Kannada", ml: "Malayalam",
};

const CATEGORIES = ["cbc", "vitamin_b12", "vitamin_d", "blood_glucose", "hba1c", "thyroid", "lipid", "liver", "kidney", "iron", "other"];

const nullable = (type: string) => ({ anyOf: [{ type }, { type: "null" }] });

const EXTRACT_SCHEMA = {
  type: "object",
  properties: {
    is_lab_report: { type: "boolean" },
    report_date: nullable("string"),
    lab_name: nullable("string"),
    category: { type: "string", enum: CATEGORIES },
    results: {
      type: "array",
      items: {
        type: "object",
        properties: {
          test_name: { type: "string" },
          value_text: { type: "string" },
          unit: nullable("string"),
          reference_text: nullable("string"),
          reference_low: nullable("number"),
          reference_high: nullable("number"),
        },
        required: ["test_name", "value_text", "unit", "reference_text", "reference_low", "reference_high"],
        additionalProperties: false,
      },
    },
  },
  required: ["is_lab_report", "report_date", "lab_name", "category", "results"],
  additionalProperties: false,
};

const EXTRACT_SYSTEM = `You transcribe laboratory test results from a medical report (a PDF or a photo). You do not interpret them.

Rules:
- Copy each test exactly as printed: test_name as written, value_text exactly as written (keep signs such as "<" or ">", and words such as "Positive"), unit exactly as written.
- reference_text is the laboratory's reference range exactly as printed for that test. reference_low and reference_high are its numeric limits when the range is a simple interval for this patient; use null for a limit that is not printed (for example "< 200" has only a high limit). If the report prints several ranges (by age, sex or category) and it is not clear which applies, keep reference_text and set both limits to null.
- Never guess, correct, convert or complete a value. If a value, unit or range is missing, blurred or unreadable, use null for it; if the value itself is unreadable, leave the whole test out.
- Do not add tests that are not on the report. Do not include patient name, address, phone, ID numbers or doctor names anywhere.
- report_date is the sample collection or report date as YYYY-MM-DD if printed, else null. lab_name is the laboratory name if printed, else null.
- category is the best single match for the report as a whole; use "other" for mixed panels.
- If the file is not a laboratory report, set is_lab_report to false and return no results.`;

const EXPLAIN_SCHEMA = {
  type: "object",
  properties: {
    summary: { type: "string" },
    nutrition_guidance: { type: "string" },
  },
  required: ["summary", "nutrition_guidance"],
  additionalProperties: false,
};

const EXPLAIN_SYSTEM = `You explain laboratory test results to the person they belong to, in plain everyday language. You are not a doctor and this is educational information only.

You receive the results as JSON. Each has the printed value, unit, the laboratory's own reference range, and a flag that was computed by software by comparing the value with that range: "low", "high", "normal", "critical", or "unknown" (no range or no number to compare).

Hard rules:
- Do not diagnose. A value outside the laboratory's range does not by itself establish a condition; say so once, briefly.
- Do not name, recommend, start, stop or change any medicine or supplement dose.
- Do not promise that food will correct a value, and do not say a food is safe for the person.
- Use only the values given. Repeat numbers, units and test names exactly as given; never convert or round them. Do not change a flag or call something low or high yourself; use the flags provided.
- For every result flagged low, high or critical, say that it should be discussed with a doctor. For "critical", say plainly that it needs medical attention today.
- If a flag is "unknown", say the report gives nothing to compare it with; do not judge it.

Write two parts:
- summary: what was tested and what stands out, grouped sensibly, most important first. Explain each medical term in a few simple words the first time, keeping the original test name. Short paragraphs or short lines; no headings, no tables.
- nutrition_guidance: general, educational food and lifestyle information related to the out-of-range results (for example foods that contain a nutrient), respecting the dietary preference and allergies if given. Keep it modest and practical. If nothing is out of range, say that no food changes are suggested by these results. End by reminding the reader to follow their doctor's advice.

Write both parts in the requested language. Keep medical test names in their original form, adding a simple translation in brackets when it helps.`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function publishableKey(): string {
  const raw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
  if (raw) {
    try {
      const keys = JSON.parse(raw) as Record<string, string>;
      const key = keys.default ?? Object.values(keys)[0];
      if (typeof key === "string" && key) return key;
    } catch {
      // fall through to the legacy key
    }
  }
  return Deno.env.get("SUPABASE_ANON_KEY") ?? "";
}

/** Calls the model with a JSON schema and returns the parsed object, or a user-facing error. */
async function askModel(
  system: string,
  content: unknown[],
  schema: unknown,
): Promise<{ data?: Record<string, unknown>; error?: string; status?: number }> {
  try {
    const anthropic = new Anthropic({ timeout: AI_TIMEOUT_MS, maxRetries: 0 });
    const response = await anthropic.beta.messages.create({
      model: MODEL,
      max_tokens: 16000,
      output_config: { effort: "medium", format: { type: "json_schema", schema } },
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system,
      // deno-lint-ignore no-explicit-any
      messages: [{ role: "user", content: content as any }],
      // deno-lint-ignore no-explicit-any
    } as any);
    if (response.stop_reason === "refusal") return { error: "The AI service could not process this report.", status: 422 };
    if (response.stop_reason === "max_tokens") return { error: "This report is too long to read in one go.", status: 422 };
    const textBlock = response.content.find((block: { type: string }) => block.type === "text") as { text: string } | undefined;
    if (!textBlock) return { error: "The AI did not return an answer. Please try again.", status: 502 };
    return { data: JSON.parse(textBlock.text) as Record<string, unknown> };
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) return { error: "The AI service is busy. Please try again in a minute.", status: 503 };
    if (error instanceof Anthropic.AuthenticationError) return { error: "The AI agent is not configured correctly (the AI API key was rejected).", status: 503 };
    if (error instanceof Anthropic.APIError) {
      console.error("AI provider error", error.status, error.message);
      return { error: "The AI service is unavailable right now. Please try again.", status: 503 };
    }
    console.error("Unexpected AI error", error instanceof Error ? error.message : "");
    return { error: "Something went wrong while reading the report. Please try again.", status: 500 };
  }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Authenticate.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Not signed in" }, 401);
  const supabase = createClient(Deno.env.get("SUPABASE_URL")!, publishableKey(), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Not signed in" }, 401);
  const uid = userData.user.id;

  if (!Deno.env.get("ANTHROPIC_API_KEY")) {
    return json({ error: "The AI agent is not configured yet (the AI API key is missing on the server)." }, 503);
  }

  // 2. Input.
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }
  const reportId = typeof body.report_id === "string" ? body.report_id : "";
  const action = body.action === "explain" ? "explain" : body.action === "extract" ? "extract" : "";
  if (!/^[0-9a-f-]{36}$/i.test(reportId) || !action) return json({ error: "Invalid request" }, 400);

  // 3. Separate consent for medical reports. Without it nothing is sent to the AI service.
  const { data: consent } = await supabase
    .from("ai_user_context_permissions").select("allowed")
    .eq("owner_id", uid).is("child_id", null).eq("context_type", "medical_reports").maybeSingle();
  if (!consent?.allowed) {
    return json({ error: "Allow AI reading of medical reports first.", code: "consent_required" }, 403);
  }

  // 4. The report must be the caller's own upload (a report shared with them is read-only).
  const { data: report } = await supabase
    .from("medical_reports").select("id, owner_id, storage_path, mime_type, file_size")
    .eq("id", reportId).maybeSingle();
  if (!report || report.owner_id !== uid) return json({ error: "Report not found" }, 404);

  // 5. Rate limit (counts audit rows, which users cannot delete). Fails closed.
  const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const { count, error: countError } = await supabase
    .from("audit_logs").select("id", { count: "exact", head: true })
    .eq("actor_id", uid).eq("action", "report_ai").gte("created_at", hourAgo);
  if (countError) return json({ error: "Something went wrong. Please try again." }, 500);
  if ((count ?? 0) >= MAX_REQUESTS_PER_HOUR) {
    return json({ error: "You have analysed many reports in the last hour. Please try again later." }, 429);
  }
  const { error: auditError } = await supabase.from("audit_logs").insert({
    actor_id: uid, action: "report_ai", entity_type: "medical_report", entity_id: reportId, details: { step: action },
  });
  if (auditError) return json({ error: "Something went wrong. Please try again." }, 500);

  const { data: settings } = await supabase
    .from("user_settings").select("preferred_language").eq("user_id", uid).maybeSingle();
  const language: string = typeof body.language === "string" && LANGUAGE_NAMES[body.language]
    ? body.language
    : (settings?.preferred_language ?? "en");

  // ------------------------------------------------------------------ extract
  if (action === "extract") {
    await supabase.from("medical_reports").update({ status: "processing" }).eq("id", reportId);
    const fail = async (message: string, status: number) => {
      await supabase.from("medical_reports").update({ status: "failed" }).eq("id", reportId);
      return json({ error: message, status: "failed" }, status);
    };

    const { data: file, error: fileError } = await supabase.storage.from(BUCKET).download(report.storage_path);
    if (fileError || !file) return await fail("The report file could not be opened. Please upload it again.", 404);
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length === 0 || bytes.length > MAX_FILE_BYTES) return await fail("The report file is empty or larger than 10 MB.", 413);
    if (report.mime_type !== "application/pdf" && bytes.length > MAX_IMAGE_BYTES) {
      return await fail("This photo is too large to read. Please take the photo again or upload a PDF.", 413);
    }
    const data = encodeBase64(bytes);
    const fileBlock = report.mime_type === "application/pdf"
      ? { type: "document", source: { type: "base64", media_type: "application/pdf", data } }
      : { type: "image", source: { type: "base64", media_type: report.mime_type, data } };

    const read = await askModel(
      EXTRACT_SYSTEM,
      [fileBlock, { type: "text", text: "Transcribe the laboratory test results from this report." }],
      EXTRACT_SCHEMA,
    );
    if (!read.data) return await fail(read.error!, read.status!);

    const rawResults = Array.isArray(read.data.results) ? read.data.results.slice(0, MAX_RESULTS) : [];
    const results = rawResults.map(validateResult).filter((r) => r !== null);
    if (read.data.is_lab_report !== true || results.length === 0) {
      return await fail("No test results could be read from this file. Check that it is a clear lab report.", 422);
    }

    const rows = results.map((r) => {
      const { flag } = flagFor(r);
      return { report_id: reportId, ...r, flag, is_user_verified: false };
    });
    // Replace anything read earlier for this report.
    await supabase.from("medical_report_analyses").delete().eq("report_id", reportId);
    await supabase.from("medical_report_results").delete().eq("report_id", reportId);
    const { error: insertError } = await supabase.from("medical_report_results").insert(rows);
    if (insertError) return await fail("The results could not be saved. Please try again.", 500);

    const reportDate = typeof read.data.report_date === "string" && /^\d{4}-\d{2}-\d{2}$/.test(read.data.report_date)
      ? read.data.report_date
      : null;
    const category = typeof read.data.category === "string" && CATEGORIES.includes(read.data.category)
      ? read.data.category
      : "other";
    const labName = typeof read.data.lab_name === "string" ? read.data.lab_name.trim().slice(0, 120) || null : null;
    await supabase.from("medical_reports")
      .update({ status: "needs_review", report_date: reportDate, lab_name: labName, category })
      .eq("id", reportId);

    return json({ status: "needs_review", results: rows.length });
  }

  // ------------------------------------------------------------------ explain
  const { data: stored } = await supabase
    .from("medical_report_results")
    .select("id, test_name, value_text, value_numeric, unit, reference_low, reference_high, reference_text")
    .eq("report_id", reportId).order("created_at").limit(MAX_RESULTS);
  if (!stored || stored.length === 0) return json({ error: "This report has no results to explain yet." }, 422);

  // Numbers and flags are recomputed here from the printed text, because the user may have
  // corrected values after the first read.
  const criticalRules: string[] = [];
  const flagged = [];
  for (const r of stored) {
    const valueNumeric = parseNumeric(r.value_text);
    const { flag, rule } = flagFor({ ...r, value_numeric: valueNumeric });
    if (rule) criticalRules.push(rule);
    await supabase.from("medical_report_results").update({ flag, value_numeric: valueNumeric }).eq("id", r.id);
    const range = r.reference_text ??
      (r.reference_low !== null || r.reference_high !== null
        ? `${r.reference_low ?? ""} - ${r.reference_high ?? ""}`.trim()
        : null);
    flagged.push({ test: r.test_name, value: r.value_text, unit: r.unit, laboratory_range: range, flag });
  }
  if (criticalRules.length) {
    await supabase.from("ai_safety_events").insert({
      owner_id: uid, event_type: "critical_lab_value", severity: "urgent",
      rule_id: [...new Set(criticalRules)].join(","), language, details: { report_id: reportId },
    });
  }

  // Dietary context only if the user allowed the AI to use it.
  const { data: permissions } = await supabase
    .from("ai_user_context_permissions").select("context_type, allowed")
    .eq("owner_id", uid).is("child_id", null).in("context_type", ["dietary_preferences", "allergies"]);
  const allowed = new Set((permissions ?? []).filter((p) => p.allowed).map((p) => p.context_type));
  const context: Record<string, unknown> = {};
  if (allowed.has("dietary_preferences")) {
    const { data: p } = await supabase.from("profiles").select("dietary_preference").eq("id", uid).maybeSingle();
    context.dietary_preference = p?.dietary_preference ?? null;
  }
  if (allowed.has("allergies")) {
    const { data: a } = await supabase.from("allergy_profiles").select("allergen").eq("owner_id", uid).is("child_id", null);
    context.allergies = (a ?? []).map((x) => x.allergen);
  }

  const explained = await askModel(
    EXPLAIN_SYSTEM,
    [{
      type: "text",
      text: `Language to write in: ${LANGUAGE_NAMES[language]}.\n\nPerson's context (may be empty): ${JSON.stringify(context)}\n\nResults:\n${JSON.stringify(flagged)}`,
    }],
    EXPLAIN_SCHEMA,
  );
  if (!explained.data) return json({ error: explained.error }, explained.status);
  const summary = typeof explained.data.summary === "string" ? explained.data.summary.trim() : "";
  const nutrition = typeof explained.data.nutrition_guidance === "string" ? explained.data.nutrition_guidance.trim() : "";
  if (!summary) return json({ error: "The AI did not return an explanation. Please try again." }, 502);

  const urgent = criticalRules.length ? urgentGuidance(language) : null;
  await supabase.from("medical_report_analyses").delete().eq("report_id", reportId);
  const { error: saveError } = await supabase.from("medical_report_analyses").insert({
    report_id: reportId, language, summary, nutrition_guidance: nutrition || null, urgent_guidance: urgent, model: MODEL,
  });
  if (saveError) return json({ error: "The explanation could not be saved. Please try again." }, 500);
  await supabase.from("medical_report_results").update({ is_user_verified: true }).eq("report_id", reportId);
  await supabase.from("medical_reports").update({ status: "analyzed" }).eq("id", reportId);

  return json({ status: "analyzed", critical: criticalRules.length > 0 });
});
