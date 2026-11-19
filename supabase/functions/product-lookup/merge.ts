// Combines the answers of several product databases into one product, field by field.
//
// Rules (from the product-discovery requirement):
// - Only records whose barcode is exactly the scanned barcode get here (callers check that).
// - Every field keeps its source, the value as the source gave it, a status and a confidence.
// - Conflicting values are never blended: the preferred source's value is shown, the others are
//   listed as alternatives, and the field is marked "conflict" for the person to decide.
// - Values converted by us (per serving -> per 100 g, kJ -> kcal, salt -> sodium) are marked "converted".
// Pure TypeScript, no Deno APIs, so it can be tested with Node.

export type SourceId = "open_food_facts" | "usda_fdc" | "nutritionix" | "fatsecret";

export const SOURCE_LABELS: Record<SourceId, string> = {
  open_food_facts: "Open Food Facts",
  usda_fdc: "USDA FoodData Central",
  nutritionix: "Nutritionix",
  fatsecret: "FatSecret",
};

/** How much a database is trusted on its own: USDA branded records are submitted by the brand owner;
 *  the others are crowd-sourced or compiled. */
const BASE_CONFIDENCE: Record<SourceId, Confidence> = {
  usda_fdc: "high",
  open_food_facts: "medium",
  nutritionix: "medium",
  fatsecret: "medium",
};

export type Confidence = "high" | "medium" | "low";
export type Basis = "per_100g" | "per_100ml";

export const NUTRIENTS = [
  "calories", "protein_g", "carbs_g", "fat_g", "saturated_fat_g", "fiber_g", "sugar_g", "sodium_mg",
] as const;
export type NutrientKey = typeof NUTRIENTS[number];

/** One database record, already converted to NutriSafe units (per 100 g or 100 ml, sodium in mg). */
export interface Candidate {
  source: SourceId;
  barcode: string;
  reference?: string | null; // link or id in that database
  name?: string | null;
  brand?: string | null;
  net_quantity?: string | null; // as printed, e.g. "250 g"
  net_quantity_amount?: number | null; // in g or ml, for comparing pack sizes
  serving_size?: number | null;
  serving_unit?: "g" | "ml" | null;
  ingredients_text?: string | null;
  allergens?: string[];
  may_contain?: string[];
  image_url?: string | null;
  basis?: Basis | null;
  nutrition?: Partial<Record<NutrientKey, number | null>>;
  /** Fields whose value we converted, with the value as the source gave it. */
  converted?: Partial<Record<string, string>>;
  /** Value as the source gave it, when it differs from the normalised one (e.g. "en:milk"). */
  originals?: Partial<Record<string, string>>;
}

export type FieldStatus = "found" | "converted" | "conflict";

export interface FieldResult {
  value: unknown;
  source: SourceId;
  source_label: string;
  original: string | null;
  status: FieldStatus;
  confidence: Confidence;
  alternatives: { source: SourceId; source_label: string; value: unknown }[];
}

export interface MergedProduct {
  fields: Record<string, FieldResult>;
  conflicts: string[];
  sources: SourceId[];
}

// ---------------------------------------------------------------------------
// Allergens: database tags and label words -> the names the app uses
// ---------------------------------------------------------------------------
const ALLERGEN_WORDS: [string, RegExp][] = [
  ["Wheat / Gluten", /\b(gluten|wheat|maida|atta|sooji|suji|rava|semolina|barley|rye|oats?)\b/i],
  ["Milk", /\b(milk|dairy|lactose|whey|casein|(?<!(cocoa|peanut|nut|shea) )butter|ghee|cream|cheese|paneer|khoa|khoya|curd|dahi)\b/i],
  ["Egg", /\beggs?\b/i],
  ["Peanut", /\b(peanuts?|groundnuts?|moongphali)\b/i],
  ["Tree nuts", /\b(tree ?nuts?|nuts|almonds?|badam|cashews?|kaju|pistachios?|pista|walnuts?|akhrot|hazelnuts?|pecans?|macadamia)\b/i],
  ["Soy", /\b(soy|soya|soybeans?)\b/i],
  ["Fish", /\bfish\b/i],
  ["Shellfish", /\b(shellfish|crustaceans?|prawns?|shrimps?|crabs?|lobsters?|molluscs?)\b/i],
  ["Sesame", /\b(sesame|til|gingelly)\b/i],
  ["Mustard", /\b(mustard|sarson|rai)\b/i],
  ["Celery", /\bcelery\b/i],
  ["Lupin", /\blupin\b/i],
  ["Sulphites", /\b(sulph?ites?|sulfites?|sulphur dioxide|sulfur dioxide)\b/i],
];

/** "en:milk", "Milk solids", "sesame-seeds" -> "Milk", "Milk", "Sesame". Unknown words are kept, capitalised. */
export function normaliseAllergen(raw: string): string | null {
  const text = raw.replace(/^[a-z]{2}:/i, "").replace(/[-_]/g, " ").trim();
  if (!text) return null;
  for (const [name, pattern] of ALLERGEN_WORDS) if (pattern.test(text)) return name;
  return text[0].toUpperCase() + text.slice(1);
}

export function normaliseAllergens(raw: (string | null | undefined)[]): string[] {
  const out: string[] = [];
  for (const item of raw) {
    const name = item ? normaliseAllergen(item) : null;
    if (name && !out.includes(name)) out.push(name);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Indian brands: spellings seen in databases and on packs -> one display name
// ---------------------------------------------------------------------------
const BRANDS: [string, RegExp][] = [
  ["Parle", /^parle( products?)?( pvt\.? ltd\.?| limited)?$|^parle[- ]?g$/i],
  ["Britannia", /^britannia( industries)?( ltd\.?| limited)?$/i],
  ["Amul", /^amul$|gujarat co-?operative milk/i],
  ["ITC", /^itc( ltd\.?| limited)?$/i],
  ["Sunfeast", /^sunfeast$/i],
  ["Aashirvaad", /^aashirvaad$/i],
  ["Bingo!", /^bingo!?$/i],
  ["Haldiram's", /^haldiram'?s?$|^haldirams?( foods?)?/i],
  ["Nestlé", /^nestl[eé]( india)?( ltd\.?| limited)?$/i],
  ["Maggi", /^maggi$/i],
  ["Patanjali", /^patanjali( ayurved)?( ltd\.?| limited)?$/i],
  ["Bikaji", /^bikaji( foods)?( international)?( ltd\.?| limited)?$/i],
  ["Tata", /^tata( consumer products)?( ltd\.?| limited)?$/i],
  ["Tata Sampann", /^tata sampann$/i],
  ["Tata Tea", /^tata tea$/i],
  ["Mother Dairy", /^mother dairy$/i],
  ["Dabur", /^dabur( india)?( ltd\.?| limited)?$/i],
  ["MTR", /^mtr( foods)?$/i],
  ["Lijjat", /^lijjat$/i],
];

export function normaliseBrand(raw: string | null | undefined): string | null {
  if (!raw) return null;
  const first = raw.split(",")[0].trim().replace(/\s+/g, " ");
  if (!first) return null;
  for (const [name, pattern] of BRANDS) if (pattern.test(first)) return name;
  // ALL-CAPS names (USDA) read better in title case.
  if (first === first.toUpperCase() && /[A-Z]{3}/.test(first)) {
    return first.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
  }
  return first;
}

// ---------------------------------------------------------------------------
// Comparing values
// ---------------------------------------------------------------------------
const NUTRIENT_TOLERANCE: Record<NutrientKey, number> = {
  calories: 5, protein_g: 0.5, carbs_g: 1, fat_g: 0.5, saturated_fat_g: 0.5,
  fiber_g: 0.5, sugar_g: 1, sodium_mg: 20,
};

export function numbersDiffer(a: number, b: number, absoluteTolerance: number): boolean {
  const diff = Math.abs(a - b);
  return diff > absoluteTolerance && diff > 0.1 * Math.max(Math.abs(a), Math.abs(b));
}

function words(text: string): Set<string> {
  return new Set(
    text.toLowerCase().replace(/\([^)]*\)|\[[^\]]*\]/g, " ").split(/[^a-z]+/).filter((w) => w.length > 2),
  );
}

/** Ingredient lists differ when they share less than half of their words. */
export function ingredientsDiffer(a: string, b: string): boolean {
  const wa = words(a), wb = words(b);
  if (wa.size === 0 || wb.size === 0) return false;
  let shared = 0;
  for (const w of wa) if (wb.has(w)) shared++;
  return shared / (wa.size + wb.size - shared) < 0.5;
}

function setsDiffer(a: string[], b: string[]): boolean {
  const sa = new Set(a), sb = new Set(b);
  if (sa.size !== sb.size) return true;
  for (const x of sa) if (!sb.has(x)) return true;
  return false;
}

// ---------------------------------------------------------------------------
// Merge
// ---------------------------------------------------------------------------
/** Text fields: Open Food Facts first (names as printed on Indian packs, images, allergen tags). */
const TEXT_ORDER: SourceId[] = ["open_food_facts", "usda_fdc", "nutritionix", "fatsecret"];
/** Nutrition: brand-owner data (USDA branded) first. */
const NUTRITION_ORDER: SourceId[] = ["usda_fdc", "open_food_facts", "nutritionix", "fatsecret"];

type Getter = (c: Candidate) => unknown;
type Differ = (a: unknown, b: unknown) => boolean;

const present = (v: unknown) =>
  v !== null && v !== undefined && !(typeof v === "string" && v.trim() === "") && !(Array.isArray(v) && v.length === 0);

function ordered(candidates: Candidate[], order: SourceId[]): Candidate[] {
  return [...candidates].sort((a, b) => order.indexOf(a.source) - order.indexOf(b.source));
}

function pick(
  key: string,
  candidates: Candidate[],
  order: SourceId[],
  get: Getter,
  differ: Differ | null,
): FieldResult | null {
  const withValue = ordered(candidates, order).filter((c) => present(get(c)));
  if (withValue.length === 0) return null;
  const chosen = withValue[0];
  const value = get(chosen);
  const others = withValue.slice(1);
  const disagreeing = differ ? others.filter((c) => differ(value, get(c))) : [];
  const agreeing = differ ? others.length - disagreeing.length : 0;
  const converted = chosen.converted?.[key];

  let status: FieldStatus = "found";
  let confidence: Confidence = BASE_CONFIDENCE[chosen.source];
  if (converted !== undefined) {
    status = "converted";
    confidence = "medium";
  }
  if (agreeing > 0 && disagreeing.length === 0 && converted === undefined) confidence = "high";
  if (disagreeing.length > 0) {
    status = "conflict";
    confidence = "low";
  }

  return {
    value,
    source: chosen.source,
    source_label: SOURCE_LABELS[chosen.source],
    original: converted ?? chosen.originals?.[key] ?? (typeof value === "object" ? JSON.stringify(value) : String(value)),
    status,
    confidence,
    alternatives: (differ ? disagreeing : others).map((c) => ({
      source: c.source, source_label: SOURCE_LABELS[c.source], value: get(c),
    })),
  };
}

export function mergeCandidates(candidates: Candidate[]): MergedProduct {
  const fields: Record<string, FieldResult> = {};
  const put = (key: string, result: FieldResult | null) => {
    if (result) fields[key] = result;
  };

  put("name", pick("name", candidates, TEXT_ORDER, (c) => c.name?.trim(), null));
  put("brand", pick("brand", candidates, TEXT_ORDER, (c) => normaliseBrand(c.brand), null));
  put("image_url", pick("image_url", candidates, TEXT_ORDER, (c) => c.image_url, null));

  // Pack size: barcodes are per pack size, so a different size means one record is wrong.
  put("net_quantity", pick("net_quantity", candidates, TEXT_ORDER, (c) => c.net_quantity?.trim(), (a, b) => {
    const ca = candidates.find((c) => c.net_quantity?.trim() === a)?.net_quantity_amount;
    const cb = candidates.find((c) => c.net_quantity?.trim() === b)?.net_quantity_amount;
    return ca != null && cb != null && Math.abs(ca - cb) > 0.02 * Math.max(ca, cb);
  }));

  put("ingredients_text", pick("ingredients_text", candidates, TEXT_ORDER, (c) => c.ingredients_text?.trim(),
    (a, b) => ingredientsDiffer(String(a), String(b))));
  put("allergens", pick("allergens", candidates, TEXT_ORDER, (c) => c.allergens,
    (a, b) => setsDiffer(a as string[], b as string[])));
  put("may_contain", pick("may_contain", candidates, TEXT_ORDER, (c) => c.may_contain,
    (a, b) => setsDiffer(a as string[], b as string[])));

  // Serving size: amount and unit travel together.
  const serving = pick("serving_size", candidates, TEXT_ORDER, (c) => c.serving_size,
    (a, b) => numbersDiffer(Number(a), Number(b), 1));
  if (serving) {
    put("serving_size", serving);
    const unitOf = candidates.find((c) => c.source === serving.source)?.serving_unit;
    if (unitOf) put("serving_unit", { ...serving, value: unitOf, original: unitOf, alternatives: [] });
  }

  // Nutrition: only records on the same basis (100 g vs 100 ml) are mixed or compared.
  const withNutrition = ordered(candidates, NUTRITION_ORDER).filter(
    (c) => c.basis && c.nutrition && NUTRIENTS.some((k) => c.nutrition![k] != null),
  );
  if (withNutrition.length > 0) {
    const basis = withNutrition[0].basis!;
    const sameBasis = withNutrition.filter((c) => c.basis === basis);
    put("basis", pick("basis", sameBasis, NUTRITION_ORDER, (c) => c.basis, null));
    for (const key of NUTRIENTS) {
      put(key, pick(key, sameBasis, NUTRITION_ORDER, (c) => c.nutrition?.[key] ?? null,
        (a, b) => numbersDiffer(Number(a), Number(b), NUTRIENT_TOLERANCE[key])));
    }
  }

  const conflicts = Object.entries(fields).filter(([, f]) => f.status === "conflict").map(([k]) => k);
  const sources = [...new Set(candidates.map((c) => c.source))];
  return { fields, conflicts, sources };
}

// ---------------------------------------------------------------------------
// Small parsers shared by the providers
// ---------------------------------------------------------------------------
/** "250 g", "1 kg", "11.93 oz/338.4 g", "500ml" -> amount in g or ml. */
export function parseQuantity(text: string | null | undefined): { amount: number; unit: "g" | "ml" } | null {
  if (!text) return null;
  const re = /(\d+(?:[.,]\d+)?)\s*(kg|g|gm|gms|grams?|mg|l|ltr|litres?|liters?|ml)\b/gi;
  let match: RegExpExecArray | null;
  while ((match = re.exec(text)) !== null) {
    const amount = Number(match[1].replace(",", "."));
    const unit = match[2].toLowerCase();
    if (!(amount > 0)) continue;
    if (unit === "kg") return { amount: amount * 1000, unit: "g" };
    if (unit === "mg") continue;
    if (unit.startsWith("g")) return { amount, unit: "g" };
    if (unit === "ml") return { amount, unit: "ml" };
    return { amount: amount * 1000, unit: "ml" }; // l, ltr, litre
  }
  return null;
}

export function toNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "") {
    const n = Number(value.replace(",", "."));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}

export function round(value: number | null | undefined, digits = 2): number | null {
  if (value == null || !Number.isFinite(value)) return null;
  const f = 10 ** digits;
  return Math.round(value * f) / f;
}
