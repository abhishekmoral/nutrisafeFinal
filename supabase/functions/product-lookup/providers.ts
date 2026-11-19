// Outside product databases. Each provider looks up ONE exact barcode and returns a Candidate in
// NutriSafe units, or says why it has none. A provider never throws: a timeout, rate limit or outage
// becomes a status, and the lookup goes on with the other databases.
//
// Keys (Supabase Edge Function secrets) - a provider without its key is skipped:
//   USDA_API_KEY                                  free key from api.data.gov (DEMO_KEY is used without it: 10 lookups/hour)
//   NUTRITIONIX_APP_ID, NUTRITIONIX_APP_KEY       paid plan needed for commercial use
//   FATSECRET_CLIENT_ID, FATSECRET_CLIENT_SECRET  barcode lookup needs Premier (or Premier Free) access

import { sameGtin } from "./barcode.ts";
import {
  type Basis,
  type Candidate,
  normaliseAllergens,
  parseQuantity,
  round,
  type SourceId,
  toNumber,
} from "./merge.ts";

export type ProviderStatus = "found" | "not_found" | "error" | "timeout" | "rate_limited" | "not_configured" | "not_allowed";

export interface ProviderResult {
  source: SourceId;
  status: ProviderStatus;
  candidate?: Candidate;
}

const TIMEOUT_MS = 7000;
const USER_AGENT = "NutriSafe/1.0 (nutrition tracking app)";

class ProviderError extends Error {
  status: ProviderStatus;
  constructor(status: ProviderStatus) {
    super(status);
    this.status = status;
  }
}

async function getJson(url: string, init: RequestInit = {}): Promise<{ status: number; body: unknown }> {
  let response: Response;
  try {
    response = await fetch(url, {
      ...init,
      headers: { "User-Agent": USER_AGENT, Accept: "application/json", ...(init.headers ?? {}) },
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  } catch (e) {
    const name = (e as Error)?.name;
    throw new ProviderError(name === "TimeoutError" || name === "AbortError" ? "timeout" : "error");
  }
  if (response.status === 429) throw new ProviderError("rate_limited");
  let body: unknown = null;
  try {
    body = await response.json();
  } catch {
    if (response.ok) throw new ProviderError("error");
  }
  return { status: response.status, body };
}

async function run(source: SourceId, work: () => Promise<Candidate | null>): Promise<ProviderResult> {
  try {
    const candidate = await work();
    return candidate ? { source, status: "found", candidate } : { source, status: "not_found" };
  } catch (e) {
    const status = e instanceof ProviderError ? e.status : "error";
    console.warn(`product-lookup: ${source} ${status}`);
    return { source, status };
  }
}

/** Per-serving values -> per 100 g/ml. Returns null when the serving weight is unknown. */
function per100(values: Record<string, number | null>, servingAmount: number | null) {
  if (!servingAmount || servingAmount <= 0) return null;
  const factor = 100 / servingAmount;
  const out: Record<string, number | null> = {};
  for (const [k, v] of Object.entries(values)) out[k] = v == null ? null : round(v * factor);
  return out;
}

// ---------------------------------------------------------------------------
// 1. Open Food Facts (open database, ODbL; strong for Indian packs)
// ---------------------------------------------------------------------------
const OFF_FIELDS = [
  "code", "product_name", "product_name_en", "brands", "quantity", "product_quantity", "product_quantity_unit",
  "serving_quantity", "serving_quantity_unit", "ingredients_text", "ingredients_text_en", "allergens_tags",
  "traces_tags", "image_front_url", "nutriments",
].join(",");

export function openFoodFacts(variants: string[]): Promise<ProviderResult> {
  return run("open_food_facts", async () => {
    // Most products are stored under the first spelling; one extra try covers UPC-A spellings.
    for (const code of variants.slice(0, 2)) {
      const { status, body } = await getJson(
        `https://world.openfoodfacts.org/api/v2/product/${code}.json?fields=${OFF_FIELDS}`,
      );
      if (status === 404) continue;
      if (status >= 500) throw new ProviderError("error");
      const b = body as { status?: number; product?: Record<string, unknown> } | null;
      if (b?.status !== 1 || !b.product) continue;
      const candidate = offToCandidate(b.product, code);
      if (candidate) return candidate;
    }
    return null;
  });
}

export function offToCandidate(p: Record<string, unknown>, code: string): Candidate | null {
  const name = String(p.product_name_en || p.product_name || "").trim();
  if (!name) return null;
  const n = (p.nutriments ?? {}) as Record<string, unknown>;
  const converted: Record<string, string> = {};

  let calories = toNumber(n["energy-kcal_100g"]);
  const kj = toNumber(n["energy-kj_100g"] ?? n["energy_100g"]);
  if (calories == null && kj != null) {
    calories = round(kj / 4.184);
    converted.calories = `${kj} kJ`;
  }
  let sodium = toNumber(n["sodium_100g"]);
  sodium = sodium == null ? null : round(sodium * 1000);
  const salt = toNumber(n["salt_100g"]);
  if (sodium == null && salt != null) {
    sodium = round(salt * 400);
    converted.sodium_mg = `${salt} g salt`;
  }

  const unit = String(p.product_quantity_unit ?? p.serving_quantity_unit ?? "").toLowerCase();
  const basis: Basis = unit === "ml" ? "per_100ml" : "per_100g";
  const pack = parseQuantity(String(p.quantity ?? ""));
  const servingAmount = toNumber(p.serving_quantity);
  const servingUnit = String(p.serving_quantity_unit ?? "").toLowerCase() === "ml" ? "ml" : "g";
  const allergenTags = (p.allergens_tags as string[] | undefined) ?? [];
  const traceTags = (p.traces_tags as string[] | undefined) ?? [];

  return {
    source: "open_food_facts",
    barcode: String(p.code ?? code),
    reference: `https://world.openfoodfacts.org/product/${p.code ?? code}`,
    name,
    brand: (p.brands as string | undefined) ?? null,
    net_quantity: (p.quantity as string | undefined)?.trim() || null,
    net_quantity_amount: pack?.amount ?? toNumber(p.product_quantity),
    serving_size: servingAmount && servingAmount > 0 ? servingAmount : null,
    serving_unit: servingAmount && servingAmount > 0 ? servingUnit : null,
    ingredients_text: String(p.ingredients_text_en || p.ingredients_text || "").trim() || null,
    allergens: normaliseAllergens(allergenTags),
    may_contain: normaliseAllergens(traceTags),
    image_url: (p.image_front_url as string | undefined) ?? null,
    basis,
    nutrition: {
      calories: round(calories),
      protein_g: round(toNumber(n["proteins_100g"])),
      carbs_g: round(toNumber(n["carbohydrates_100g"])),
      fat_g: round(toNumber(n["fat_100g"])),
      saturated_fat_g: round(toNumber(n["saturated-fat_100g"])),
      fiber_g: round(toNumber(n["fiber_100g"])),
      sugar_g: round(toNumber(n["sugars_100g"])),
      sodium_mg: sodium,
    },
    converted,
    originals: {
      allergens: allergenTags.join(", ") || "",
      may_contain: traceTags.join(", ") || "",
    },
  };
}

// ---------------------------------------------------------------------------
// 2. USDA FoodData Central (public domain; branded records come from brand owners, mostly US market)
// ---------------------------------------------------------------------------
const USDA_NUTRIENTS: Record<string, string> = {
  "208": "calories", "203": "protein_g", "205": "carbs_g", "204": "fat_g",
  "606": "saturated_fat_g", "291": "fiber_g", "269": "sugar_g", "307": "sodium_mg",
};

export function usda(gtin13: string, variants: string[]): Promise<ProviderResult> {
  return run("usda_fdc", async () => {
    const key = Deno.env.get("USDA_API_KEY") || "DEMO_KEY";
    const query = encodeURIComponent(variants[variants.length > 1 ? 1 : 0]); // USDA mostly stores UPC-A spellings
    const { status, body } = await getJson(
      `https://api.nal.usda.gov/fdc/v1/foods/search?api_key=${key}&query=${query}&dataType=Branded&pageSize=10`,
    );
    if (status === 403) throw new ProviderError("not_allowed");
    if (status !== 200) throw new ProviderError("error");
    const foods = ((body as { foods?: Record<string, unknown>[] })?.foods ?? [])
      // Exact barcode only: a name match can be another pack size or another country's recipe.
      .filter((f) => sameGtin(String(f.gtinUpc ?? ""), gtin13));
    if (foods.length === 0) return null;
    return usdaToCandidate(foods[0]);
  });
}

export function usdaToCandidate(f: Record<string, unknown>): Candidate {
  const nutrition: Record<string, number | null> = {};
  for (const item of (f.foodNutrients as Record<string, unknown>[] | undefined) ?? []) {
    const key = USDA_NUTRIENTS[String(item.nutrientNumber ?? "")];
    if (key && nutrition[key] == null) nutrition[key] = round(toNumber(item.value));
  }
  const unit = String(f.servingSizeUnit ?? "").toLowerCase();
  const isLiquid = unit === "ml" || unit === "mlt";
  const pack = parseQuantity(String(f.packageWeight ?? ""));
  const serving = toNumber(f.servingSize);
  return {
    source: "usda_fdc",
    barcode: String(f.gtinUpc ?? ""),
    reference: f.fdcId ? `https://fdc.nal.usda.gov/food-details/${f.fdcId}/nutrients` : null,
    name: (f.description as string | undefined) ?? null,
    brand: (f.brandName as string | undefined) || (f.brandOwner as string | undefined) || null,
    net_quantity: (f.packageWeight as string | undefined) ?? null,
    net_quantity_amount: pack?.amount ?? null,
    serving_size: serving && serving > 0 ? round(serving) : null,
    serving_unit: serving && serving > 0 ? (isLiquid ? "ml" : "g") : null,
    ingredients_text: (f.ingredients as string | undefined) ?? null,
    allergens: [],
    may_contain: [],
    image_url: null,
    basis: isLiquid ? "per_100ml" : "per_100g",
    nutrition,
  };
}

// ---------------------------------------------------------------------------
// 3. Nutritionix (commercial licence; values per serving)
// ---------------------------------------------------------------------------
export function nutritionix(variants: string[]): Promise<ProviderResult> {
  const appId = Deno.env.get("NUTRITIONIX_APP_ID");
  const appKey = Deno.env.get("NUTRITIONIX_APP_KEY");
  if (!appId || !appKey) return Promise.resolve({ source: "nutritionix", status: "not_configured" });
  return run("nutritionix", async () => {
    const { status, body } = await getJson(
      `https://trackapi.nutritionix.com/v2/search/item/?upc=${variants[variants.length > 1 ? 1 : 0]}`,
      { headers: { "x-app-id": appId, "x-app-key": appKey } },
    );
    if (status === 404) return null;
    if (status === 401 || status === 403) throw new ProviderError("not_allowed");
    if (status !== 200) throw new ProviderError("error");
    const food = ((body as { foods?: Record<string, unknown>[] })?.foods ?? [])[0];
    if (!food) return null;
    const grams = toNumber(food.serving_weight_grams);
    const perServing = {
      calories: toNumber(food.nf_calories), protein_g: toNumber(food.nf_protein),
      carbs_g: toNumber(food.nf_total_carbohydrate), fat_g: toNumber(food.nf_total_fat),
      saturated_fat_g: toNumber(food.nf_saturated_fat), fiber_g: toNumber(food.nf_dietary_fiber),
      sugar_g: toNumber(food.nf_sugars), sodium_mg: toNumber(food.nf_sodium),
    };
    const nutrition = per100(perServing, grams);
    const servingText = `${food.serving_qty ?? ""} ${food.serving_unit ?? ""} (${grams ?? "?"} g)`.trim();
    const converted: Record<string, string> = {};
    if (nutrition) {
      for (const [k, v] of Object.entries(perServing)) if (v != null) converted[k] = `${v} per serving ${servingText}`;
    }
    return {
      source: "nutritionix",
      barcode: variants[0],
      reference: (food.nix_item_id as string | undefined) ?? null,
      name: (food.food_name as string | undefined) ?? null,
      brand: (food.brand_name as string | undefined) ?? null,
      serving_size: grams && grams > 0 ? round(grams) : null,
      serving_unit: grams && grams > 0 ? "g" : null,
      ingredients_text: (food.nf_ingredient_statement as string | undefined) ?? null,
      image_url: ((food.photo as Record<string, unknown> | undefined)?.thumb as string | undefined) ?? null,
      basis: nutrition ? "per_100g" : null,
      nutrition: nutrition ?? undefined,
      converted,
    };
  });
}

// ---------------------------------------------------------------------------
// 4. FatSecret Platform (licence allows storing only ids, so its values are never cached)
// ---------------------------------------------------------------------------
let fatSecretToken: { value: string; expires: number } | null = null;

async function fatSecretAccessToken(id: string, secret: string): Promise<string> {
  if (fatSecretToken && fatSecretToken.expires > Date.now() + 60_000) return fatSecretToken.value;
  const { status, body } = await getJson("https://oauth.fatsecret.com/connect/token", {
    method: "POST",
    headers: {
      Authorization: `Basic ${btoa(`${id}:${secret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials&scope=premier%20barcode",
  });
  const b = body as { access_token?: string; expires_in?: number } | null;
  if (status === 400 || status === 401) throw new ProviderError("not_allowed");
  if (status !== 200 || !b?.access_token) throw new ProviderError("error");
  fatSecretToken = { value: b.access_token, expires: Date.now() + (b.expires_in ?? 3600) * 1000 };
  return b.access_token;
}

export function fatSecretConfigured(): boolean {
  return !!(Deno.env.get("FATSECRET_CLIENT_ID") && Deno.env.get("FATSECRET_CLIENT_SECRET"));
}

export function fatSecret(gtin13: string): Promise<ProviderResult> {
  const id = Deno.env.get("FATSECRET_CLIENT_ID");
  const secret = Deno.env.get("FATSECRET_CLIENT_SECRET");
  if (!id || !secret) return Promise.resolve({ source: "fatsecret", status: "not_configured" });
  if (gtin13.length !== 13) return Promise.resolve({ source: "fatsecret", status: "not_found" });
  return run("fatsecret", async () => {
    const token = await fatSecretAccessToken(id, secret);
    const { status, body } = await getJson(
      `https://platform.fatsecret.com/rest/food/barcode/find-by-id/v2?barcode=${gtin13}&format=json&flag_default_serving=true`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    const b = body as { food?: Record<string, unknown>; error?: { code?: number | string } } | null;
    const code = Number(b?.error?.code ?? 0);
    if (code === 211 || code === 106) return null; // no food for this barcode
    if (code === 14 || code === 12 || code === 21 || status === 401 || status === 403) throw new ProviderError("not_allowed");
    if (status !== 200 || !b?.food) throw new ProviderError("error");
    const food = b.food;
    const raw = (food.servings as { serving?: unknown } | undefined)?.serving;
    const servings = (Array.isArray(raw) ? raw : raw ? [raw] : []) as Record<string, unknown>[];
    const serving = servings.find((s) => s.is_default === "1" && toNumber(s.metric_serving_amount))
      ?? servings.find((s) => toNumber(s.metric_serving_amount));
    let nutrition: Record<string, number | null> | null = null;
    let basis: Basis | null = null;
    const converted: Record<string, string> = {};
    if (serving) {
      const amount = toNumber(serving.metric_serving_amount);
      const unit = String(serving.metric_serving_unit ?? "g").toLowerCase();
      const perServing = {
        calories: toNumber(serving.calories), protein_g: toNumber(serving.protein),
        carbs_g: toNumber(serving.carbohydrate), fat_g: toNumber(serving.fat),
        saturated_fat_g: toNumber(serving.saturated_fat), fiber_g: toNumber(serving.fiber),
        sugar_g: toNumber(serving.sugar), sodium_mg: toNumber(serving.sodium),
      };
      nutrition = per100(perServing, amount);
      basis = nutrition ? (unit === "ml" ? "per_100ml" : "per_100g") : null;
      for (const [k, v] of Object.entries(perServing)) {
        if (v != null) converted[k] = `${v} per ${serving.serving_description ?? "serving"} (${amount} ${unit})`;
      }
    }
    return {
      source: "fatsecret",
      barcode: gtin13,
      reference: (food.food_id as string | undefined) ?? null,
      name: (food.food_name as string | undefined) ?? null,
      brand: (food.brand_name as string | undefined) ?? null,
      basis,
      nutrition: nutrition ?? undefined,
      converted,
    };
  });
}
