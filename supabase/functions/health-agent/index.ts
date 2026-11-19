// NutriSafe - AI Family Health Agent (Supabase Edge Function).
//
// Flow: authenticate -> rate limit -> rule-based safety screening -> load ONLY the context the
// user allowed -> call Claude -> post-checks (allergens, urgent notice) -> save -> reply.
//
// Secret you must add in the Supabase dashboard (Edge Functions -> Secrets): ANTHROPIC_API_KEY
// SUPABASE_URL and the project's API keys are provided by the platform.
// All database access uses the caller's JWT, so Row Level Security applies to every query.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk";
import { screenMessage, urgentNotice } from "./safety.ts";

const MODEL = "claude-opus-5-5";
const MAX_MESSAGE_CHARS = 4000;
const MAX_MESSAGES_PER_HOUR = 40;
const HISTORY_LIMIT = 20;
const AI_TIMEOUT_MS = 110_000; // stay below the platform's request limit

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  hi: "Hindi",
  hinglish: "Hinglish (Hindi written in Latin script, mixed with English)",
  bn: "Bengali",
  ta: "Tamil",
  te: "Telugu",
  mr: "Marathi",
  gu: "Gujarati",
  pa: "Punjabi",
  ur: "Urdu",
  kn: "Kannada",
  ml: "Malayalam",
};

// Stable instructions first (cacheable); per-user context is appended after.
const SYSTEM_PROMPT = `You are the NutriSafe Family Health Agent: one assistant that helps a person with everyday food, nutrition and wellness questions. You give general, educational guidance. You are not a doctor and you do not replace one.

What you can do: understand reported symptoms and ask follow-up questions, evaluate the logged food diary against the user's own goals, suggest foods and explain why each fits, draft meal plans (meal, foods, quantity, estimated calories and macros, why it is included, substitutions), and summarise progress.

Hard rules (they apply in every language and never relax):
- Never diagnose a condition, prescribe or name a dose of any medicine, or tell someone to start, stop or change a medication.
- Never promise a result or a recovery time. A plan is a monitoring plan, not a cure.
- Never say a food is safe for someone. Allergy information can be incomplete; tell the user to check labels.
- Never suggest extreme calorie restriction, fasting for weight loss, or rapid weight loss.
- Never claim that food alone will correct a deficiency or an abnormal lab result; recommend discussing abnormal results with a doctor.
- Never invent data. If a value, a report result or a diary entry is not in the context below, say you do not have it and ask.
- Nothing you suggest is recorded as eaten. The user logs food themself in the Food Diary after eating.
- For a child, an older adult, pregnancy, or a chronic condition (diabetes, kidney, heart, thyroid...), be more conservative and recommend professional advice sooner.
- If the user describes warning signs (for example severe or worsening pain, blood in stool or vomit, persistent vomiting, inability to pass gas or stool with pain, chest pain, trouble breathing, fainting, signs of a severe allergic reaction, thoughts of self-harm), put getting medical help first and do not answer with food suggestions alone.

How to answer:
- Reply in the language given under "Reply language". Keep numbers, units, test names and medical terms exactly as they are; add a simple translation of a medical term when it helps.
- When symptoms are reported and you lack key facts (duration, severity, what they eat and drink, relevant medicines, warning signs), ask up to four short follow-up questions before recommending.
- Use only the user context provided below, and respect dietary preference, allergies and intolerances in every food you mention.
- Say clearly what comes from the user's logged data and what is your general suggestion. Nutrition numbers you state are estimates; say so.
- Be warm, plain and brief: short paragraphs or short lists, no headings unless the answer is a plan. End with one clear next step.`;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** The project's publishable key (new API keys), falling back to the legacy anon key. */
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

function localDate(offsetDays = 0, tzOffsetMinutes = 0): string {
  const d = new Date(Date.now() + tzOffsetMinutes * 60_000 - offsetDays * 86_400_000);
  return d.toISOString().slice(0, 10);
}

/** Loads only the context types the user switched on. */
async function loadContext(supabase: SupabaseClient, uid: string, tzOffsetMinutes: number) {
  const { data: permissionRows } = await supabase
    .from("ai_user_context_permissions")
    .select("context_type, allowed")
    .eq("owner_id", uid)
    .is("child_id", null);
  const allowed = new Set(
    (permissionRows ?? []).filter((p) => p.allowed).map((p) => p.context_type as string),
  );

  const context: Record<string, unknown> = {};
  let allergens: string[] = [];

  const needsProfile = ["profile", "body_metrics", "dietary_preferences"].some((t) => allowed.has(t));
  if (needsProfile) {
    const { data: p } = await supabase.from("profiles").select("*").eq("id", uid).maybeSingle();
    if (p) {
      if (allowed.has("profile")) {
        const age = p.date_of_birth
          ? Math.floor((Date.now() - Date.parse(p.date_of_birth)) / (365.25 * 86_400_000))
          : null;
        context.profile = {
          first_name: (p.full_name ?? "").split(" ")[0] || null,
          age_years: age,
          gender: p.gender,
          activity_level: p.activity_level,
          location: p.location,
        };
      }
      if (allowed.has("body_metrics")) {
        context.body_metrics = { height_cm: p.height_cm, weight_kg: p.weight_kg };
      }
      if (allowed.has("dietary_preferences")) {
        context.dietary_preference = p.dietary_preference;
      }
    }
  }

  if (allowed.has("allergies")) {
    const [{ data: a }, { data: i }] = await Promise.all([
      supabase.from("allergy_profiles").select("allergen, severity").eq("owner_id", uid).is("child_id", null),
      supabase.from("intolerance_profiles").select("food").eq("owner_id", uid).is("child_id", null),
    ]);
    allergens = (a ?? []).map((r) => r.allergen as string);
    context.allergies = a ?? [];
    context.intolerances = (i ?? []).map((r) => r.food);
  }

  if (allowed.has("health_goals")) {
    const [{ data: goals }, { data: targets }] = await Promise.all([
      supabase.from("user_health_goals").select("goal_type").eq("owner_id", uid).is("child_id", null).eq("is_active", true),
      supabase.from("nutrition_goals").select("calories, protein_g, carbs_g, fat_g, fiber_g, sodium_mg, water_ml").eq("owner_id", uid).is("child_id", null).maybeSingle(),
    ]);
    context.wellness_goals = (goals ?? []).map((g) => g.goal_type);
    context.daily_targets_set_by_user = targets ?? null;
  }

  if (allowed.has("food_diary")) {
    const from = localDate(3, tzOffsetMinutes);
    const [{ data: entries }, { data: water }] = await Promise.all([
      supabase
        .from("meal_entries")
        .select("entry_date, meal_type, food_name, quantity, unit, calories, protein_g, carbs_g, fat_g, fiber_g, sugar_g, sodium_mg, nutrition_quality")
        .eq("owner_id", uid).is("child_id", null).gte("entry_date", from)
        .order("entry_date").limit(200),
      supabase.from("water_logs").select("log_date, amount_ml").eq("owner_id", uid).is("child_id", null).gte("log_date", from),
    ]);
    const waterByDay: Record<string, number> = {};
    for (const w of water ?? []) waterByDay[w.log_date] = (waterByDay[w.log_date] ?? 0) + w.amount_ml;
    context.food_diary_last_4_days = {
      today: localDate(0, tzOffsetMinutes),
      note: "User-logged. Null nutrient = unknown, not zero. Days without entries may simply be unlogged.",
      entries: entries ?? [],
      water_ml_by_day: waterByDay,
    };
  }

  if (allowed.has("symptoms")) {
    const { data: symptoms } = await supabase
      .from("user_symptoms")
      .select("symptom, severity, started_on, notes, recorded_at")
      .eq("owner_id", uid).is("child_id", null)
      .order("recorded_at", { ascending: false }).limit(15);
    context.reported_symptoms = symptoms ?? [];
  }

  if (allowed.has("progress")) {
    const { data: progress } = await supabase
      .from("health_progress_logs")
      .select("log_date, weight_kg, bowel_movements, energy_level, followed_meal_plan, symptom_change")
      .eq("owner_id", uid).is("child_id", null)
      .order("log_date", { ascending: false }).limit(14);
    context.progress_logs_user_reported = progress ?? [];
  }

  return { context, allergens, historyAllowed: allowed.has("ai_history") };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Authenticate the caller (the platform also verifies the JWT before this code runs).
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

  // 2. Validate input.
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }
  const message = typeof body.message === "string" ? body.message.trim() : "";
  if (!message) return json({ error: "Message is empty" }, 400);
  if (message.length > MAX_MESSAGE_CHARS) {
    return json({ error: `Message is too long (max ${MAX_MESSAGE_CHARS} characters)` }, 400);
  }
  let conversationId = typeof body.conversation_id === "string" ? body.conversation_id : null;
  const tzOffsetMinutes =
    typeof body.tz_offset_minutes === "number" && Math.abs(body.tz_offset_minutes) <= 840
      ? body.tz_offset_minutes
      : 330;

  // 3. Rate limit per user. It counts rows in audit_logs, which users can add to but never
  //    delete, so clearing a chat does not reset the limit. Fails closed.
  const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
  const { count, error: countError } = await supabase
    .from("audit_logs")
    .select("id", { count: "exact", head: true })
    .eq("actor_id", uid).eq("action", "ai_request").gte("created_at", hourAgo);
  if (countError) return json({ error: "Something went wrong. Please try again." }, 500);
  if ((count ?? 0) >= MAX_MESSAGES_PER_HOUR) {
    return json({ error: "You have sent many messages in the last hour. Please try again later." }, 429);
  }
  const { error: auditError } = await supabase
    .from("audit_logs")
    .insert({ actor_id: uid, action: "ai_request", entity_type: "ai_conversation" });
  if (auditError) return json({ error: "Something went wrong. Please try again." }, 500);

  // 4. Settings, permitted context, conversation history.
  const { data: settings } = await supabase
    .from("user_settings").select("preferred_language, auto_detect_language").eq("user_id", uid).maybeSingle();
  const requestedLanguage = typeof body.language === "string" && LANGUAGE_NAMES[body.language]
    ? body.language
    : null;
  const preferred: string = requestedLanguage ?? settings?.preferred_language ?? "en";
  const autoDetect = requestedLanguage ? false : (settings?.auto_detect_language ?? true);

  const { context, allergens, historyAllowed } = await loadContext(supabase, uid, tzOffsetMinutes);

  if (conversationId) {
    const { data: conv } = await supabase
      .from("ai_conversations").select("id").eq("id", conversationId).eq("owner_id", uid).maybeSingle();
    if (!conv) conversationId = null;
  }
  if (!conversationId) {
    const { data: conv, error } = await supabase
      .from("ai_conversations")
      .insert({ owner_id: uid, title: message.slice(0, 60), language: preferred })
      .select("id").single();
    if (error || !conv) return json({ error: "Could not start the conversation" }, 500);
    conversationId = conv.id as string;
  }

  let history: { role: "user" | "assistant"; content: string }[] = [];
  if (historyAllowed) {
    const { data: rows } = await supabase
      .from("ai_messages").select("role, content")
      .eq("conversation_id", conversationId)
      .order("created_at", { ascending: false }).limit(HISTORY_LIMIT);
    history = (rows ?? []).reverse() as typeof history;
    // The API needs the first message to be from the user.
    while (history.length && history[0].role !== "user") history.shift();
  }

  // 5. Rule-based safety screening. Runs before, and independently of, the model.
  const screening = screenMessage(message);
  if (screening.flagged) {
    await supabase.from("ai_safety_events").insert({
      owner_id: uid,
      conversation_id: conversationId,
      event_type: screening.level === "emergency" ? "emergency" : "red_flag_symptom",
      severity: screening.level,
      rule_id: screening.ruleIds.join(","),
      language: preferred,
      details: { rules: screening.ruleIds },
    });
  }

  // 6. Call the model.
  const languageLine = autoDetect
    ? `Reply language: the language the user writes in (if unclear, ${LANGUAGE_NAMES[preferred]}).`
    : `Reply language: ${LANGUAGE_NAMES[preferred]}.`;
  const contextBlock = Object.keys(context).length
    ? `User context the user allowed you to see (JSON):\n${JSON.stringify(context)}`
    : "The user has not allowed access to their profile or diary. Do not assume anything about them; ask for what you need, and mention once that they can enable personalisation in Settings.";
  const safetyLine = screening.flagged
    ? `\n\nSAFETY: the user's message matched warning-sign rules (${screening.ruleIds.join(", ")}). Start by telling them clearly and calmly to get medical help ${screening.level === "emergency" ? "immediately (emergency services)" : "soon (a doctor today)"}. Do not give food suggestions as the main answer.`
    : "";

  let reply = "";
  try {
    // Reads ANTHROPIC_API_KEY from the function's secrets.
    const anthropic = new Anthropic({ timeout: AI_TIMEOUT_MS, maxRetries: 0 });
    const response = await anthropic.beta.messages.create({
      model: MODEL,
      max_tokens: 8000,
      output_config: { effort: "medium" },
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: [
        { type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } },
        { type: "text", text: `${languageLine}\n\n${contextBlock}${safetyLine}` },
      ],
      messages: [...history, { role: "user", content: message }],
    });

    if (response.stop_reason === "refusal") {
      reply = "I can't help with that request. If this is about your health, please speak to a doctor.";
    } else {
      reply = response.content
        .filter((block) => block.type === "text")
        .map((block) => (block as { text: string }).text)
        .join("\n")
        .trim();
      if (response.stop_reason === "max_tokens") reply += "\n\n(The answer was cut short. Ask me to continue.)";
    }
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      return json({ error: "The AI service is busy. Please try again in a minute.", conversation_id: conversationId }, 503);
    }
    if (error instanceof Anthropic.AuthenticationError) {
      console.error("AI credentials are missing or invalid");
      return json({ error: "The AI agent is not configured correctly (the AI API key was rejected).", conversation_id: conversationId }, 503);
    }
    if (error instanceof Anthropic.APIError) {
      console.error("AI provider error", error.status, error.message);
      return json({ error: "The AI service is unavailable right now. Please try again.", conversation_id: conversationId }, 503);
    }
    console.error("Unexpected AI error", error instanceof Error ? error.message : "");
    return json({ error: "Something went wrong. Please try again.", conversation_id: conversationId }, 500);
  }
  if (!reply) return json({ error: "The AI did not return an answer. Please try again.", conversation_id: conversationId }, 502);

  // 7. Post-checks that do not depend on the model following instructions.
  const urgent = screening.flagged ? urgentNotice(screening.level, preferred) : null;
  const mentioned = allergens.filter((a) =>
    a.toLowerCase().split(/[\/,]/).map((w) => w.trim()).some((w) => w && reply.toLowerCase().includes(w))
  );
  const allergyNote = mentioned.length
    ? `Allergy check: this answer mentions ${mentioned.join(", ")}, which is on your allergy list. Please avoid it and check labels.`
    : null;
  // Urgent notice first, then the answer, then the allergy note.
  const finalReply = [urgent, reply, allergyNote].filter(Boolean).join("\n\n");

  // 8. Save the exchange.
  const meta = { safety_level: screening.flagged ? screening.level : null, allergens_mentioned: mentioned };
  const { error: saveError } = await supabase.from("ai_messages").insert([
    { conversation_id: conversationId, owner_id: uid, role: "user", content: message },
    { conversation_id: conversationId, owner_id: uid, role: "assistant", content: finalReply, metadata: meta },
  ]);
  if (saveError) console.error("Could not save the messages", saveError.code);
  await supabase.from("ai_conversations").update({ language: preferred }).eq("id", conversationId);

  return json({
    conversation_id: conversationId,
    reply: finalReply,
    safety: { flagged: screening.flagged, level: screening.flagged ? screening.level : null },
  });
});
