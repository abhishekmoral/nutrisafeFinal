// NutriSafe - find a packaged product by its barcode (Supabase Edge Function).
//
// Order, all automatic (the app never has to pick a database):
//   1. NutriSafe database: the caller's own confirmed products, then curated rows checked against
//      official manufacturer data. A hit here is returned straight away.
//   2. Cache of earlier outside lookups (product_lookup_cache).
//   3. Outside databases, all asked at once, exact barcode only:
//      Open Food Facts, USDA FoodData Central, Nutritionix, FatSecret.
//   4. Their answers are merged field by field; disagreements are flagged, never blended.
// If nothing matches, the app moves on to reading the package label (OCR) on the phone.
//
// Response: { status: "saved" | "found" | "not_found", barcode, fields, conflicts, providers, ... }

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";
import { isIndianBarcode, normaliseBarcode } from "./barcode.ts";
import { type Candidate, mergeCandidates, NUTRIENTS, type SourceId, SOURCE_LABELS } from "./merge.ts";
import {
  fatSecret,
  fatSecretConfigured,
  nutritionix,
  openFoodFacts,
  type ProviderResult,
  type ProviderStatus,
  usda,
} from "./providers.ts";

const DAY_MS = 86_400_000;
const FOUND_TTL_MS = 30 * DAY_MS; // a product found everywhere it was asked for
const SHORT_TTL_MS = 1 * DAY_MS; // not found, or found while some database was down
const MAX_OUTSIDE_LOOKUPS_PER_HOUR = 120;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

/** Reads a key from the new JSON key dictionaries, falling back to the legacy variable. */
function projectKey(dictionaryVar: string, legacyVar: string): string {
  const raw = Deno.env.get(dictionaryVar);
  if (raw) {
    try {
      const keys = JSON.parse(raw) as Record<string, string>;
      const key = keys.default ?? Object.values(keys)[0];
      if (typeof key === "string" && key) return key;
    } catch {
      // fall through to the legacy key
    }
  }
  return Deno.env.get(legacyVar) ?? "";
}

interface ProviderReport {
  source: string;
  label: string;
  status: ProviderStatus | "cached";
}

const report = (r: ProviderResult): ProviderReport => ({
  source: r.source, label: SOURCE_LABELS[r.source], status: r.status,
});

/** A product saved in NutriSafe, in the same field shape as a merged lookup. */
function savedProductResponse(row: Record<string, unknown>, gtin13: string, uid: string) {
  const own = row.created_by === uid;
  const sources = (row.field_sources ?? {}) as Record<string, Record<string, unknown>>;
  const nutrition = ((row.food_nutrition as Record<string, unknown>[] | null) ?? [])[0] ?? {};
  const fallbackSource = own ? "user" : "manufacturer";
  const fallbackLabel = own ? "Saved by you" : "NutriSafe (checked against manufacturer data)";
  const field = (key: string, value: unknown) => {
    if (value === null || value === undefined || value === "" || (Array.isArray(value) && value.length === 0)) return null;
    const info = sources[key] ?? {};
    return {
      value,
      source: (info.source as string | undefined) ?? fallbackSource,
      source_label: (info.source_label as string | undefined) ?? fallbackLabel,
      original: (info.original as string | undefined) ?? null,
      status: (info.status as string | undefined) ?? (own ? "user_confirmed" : "verified"),
      confidence: (info.confidence as string | undefined) ?? "high",
      alternatives: [],
    };
  };
  const fields: Record<string, unknown> = {};
  const add = (key: string, value: unknown) => {
    const f = field(key, value);
    if (f) fields[key] = f;
  };
  add("name", row.name);
  add("brand", row.brand);
  add("image_url", row.image_url);
  add("net_quantity", row.net_quantity);
  add("ingredients_text", row.ingredients_text);
  add("allergens", row.allergens);
  add("may_contain", row.may_contain);
  add("serving_size", row.serving_size == null ? null : Number(row.serving_size));
  add("serving_unit", row.serving_unit);
  if (nutrition.basis === "per_100g" || nutrition.basis === "per_100ml" || nutrition.basis === "per_serving") {
    add("basis", nutrition.basis);
    for (const key of NUTRIENTS) add(key, nutrition[key] == null ? null : Number(nutrition[key]));
  }
  return {
    status: "saved",
    barcode: (row.barcode as string | null) ?? gtin13,
    product_id: row.id,
    verification_status: row.verification_status,
    saved_by_you: own,
    fields,
    conflicts: [],
    providers: [{ source: "nutrisafe", label: "NutriSafe", status: "found" }],
  };
}

async function readCache(admin: SupabaseClient, gtin13: string) {
  const { data, error } = await admin
    .from("product_lookup_cache").select("candidates, providers, expires_at")
    .eq("barcode", gtin13).gt("expires_at", new Date().toISOString()).maybeSingle();
  if (error) console.warn("product-lookup: cache read failed", error.message);
  return data as { candidates: Candidate[]; providers: ProviderReport[] } | null;
}

async function writeCache(admin: SupabaseClient, gtin13: string, results: ProviderResult[]) {
  // FatSecret's licence allows keeping only ids, so its answer is never stored.
  const storable = results.filter((r) => r.source !== "fatsecret");
  const failed = storable.some((r) => r.status === "error" || r.status === "timeout" || r.status === "rate_limited");
  const candidates = storable.filter((r) => r.candidate).map((r) => r.candidate!);
  if (candidates.length === 0 && failed) return; // a database was down: try again next time
  const ttl = candidates.length > 0 && !failed ? FOUND_TTL_MS : SHORT_TTL_MS;
  const { error } = await admin.from("product_lookup_cache").upsert({
    barcode: gtin13,
    found: candidates.length > 0,
    candidates,
    providers: storable.map(report),
    fetched_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + ttl).toISOString(),
  });
  if (error) console.warn("product-lookup: cache write failed", error.message);
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // 1. Authenticate.
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "").trim();
  if (!token) return json({ error: "Not signed in" }, 401);
  const url = Deno.env.get("SUPABASE_URL")!;
  const supabase = createClient(url, projectKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"), {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "Not signed in" }, 401);
  const uid = userData.user.id;

  // 2. Input.
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }
  const barcode = normaliseBarcode(
    typeof body.barcode === "string" ? body.barcode : "",
    typeof body.format === "string" ? body.format : undefined,
  );
  if (!barcode) {
    return json({ error: "This barcode could not be read correctly. Please scan it again.", code: "invalid_barcode" }, 400);
  }
  const { gtin13, variants } = barcode;
  const indian = isIndianBarcode(gtin13);

  // 3. NutriSafe database (RLS: own rows and curated rows only). Own confirmed copy first.
  const { data: saved, error: savedError } = await supabase
    .from("food_products")
    .select("id, barcode, name, brand, net_quantity, serving_size, serving_unit, image_url, allergens, may_contain, ingredients_text, source, field_sources, verification_status, created_by, food_nutrition(*)")
    .in("barcode", variants)
    .limit(5);
  if (savedError) console.warn("product-lookup: saved product read failed", savedError.message);
  const savedRows = (saved ?? []) as Record<string, unknown>[];
  const savedRow = savedRows.find((r) => r.created_by === uid)
    ?? savedRows.find((r) => r.created_by === null && r.verification_status === "verified");
  if (savedRow) return json({ ...savedProductResponse(savedRow, gtin13, uid), indian_barcode: indian });

  // 4. Cache, then the outside databases.
  const admin = createClient(url, projectKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const cached = await readCache(admin, gtin13);
  let candidates: Candidate[];
  let providers: ProviderReport[];

  if (cached) {
    candidates = cached.candidates ?? [];
    providers = (cached.providers ?? []).map((p) => ({ ...p, status: p.status === "found" ? "cached" : p.status }));
    if (fatSecretConfigured()) {
      const live = await fatSecret(gtin13);
      if (live.candidate) candidates.push(live.candidate);
      providers.push(report(live));
    }
  } else {
    // Rate limit outside lookups per person (protects the databases' quotas). Counted in audit_logs.
    const hourAgo = new Date(Date.now() - 3_600_000).toISOString();
    const { count } = await supabase
      .from("audit_logs").select("id", { count: "exact", head: true })
      .eq("actor_id", uid).eq("action", "product_lookup").gte("created_at", hourAgo);
    if ((count ?? 0) >= MAX_OUTSIDE_LOOKUPS_PER_HOUR) {
      return json({ error: "You have looked up many new products in the last hour. Please try again later.", code: "rate_limited" }, 429);
    }
    await supabase.from("audit_logs").insert({
      actor_id: uid, action: "product_lookup", entity_type: "barcode", details: { barcode: gtin13 },
    });

    const results = await Promise.all([
      openFoodFacts(variants),
      usda(gtin13, variants),
      nutritionix(variants),
      fatSecret(gtin13),
    ]);
    await writeCache(admin, gtin13, results);
    candidates = results.filter((r) => r.candidate).map((r) => r.candidate!);
    providers = results.map(report);
  }

  if (candidates.length === 0) {
    return json({ status: "not_found", barcode: gtin13, indian_barcode: indian, fields: {}, conflicts: [], providers });
  }

  const merged = mergeCandidates(candidates);
  return json({
    status: "found",
    barcode: gtin13,
    indian_barcode: indian,
    fields: merged.fields,
    conflicts: merged.conflicts,
    sources: merged.sources.map((s: SourceId) => ({ source: s, label: SOURCE_LABELS[s] })),
    references: candidates.map((c) => ({ source: c.source, reference: c.reference ?? null })),
    providers,
  });
});
