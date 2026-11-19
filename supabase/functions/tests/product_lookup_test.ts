// Tests for barcode normalisation and the field-by-field merge used by the product-lookup function.
// Run with:  node supabase/functions/tests/product_lookup_test.ts   (Node 24+)

import { hasValidCheckDigit, normaliseBarcode, sameGtin, upcEToUpcA } from "../product-lookup/barcode.ts";
import {
  type Candidate,
  ingredientsDiffer,
  mergeCandidates,
  normaliseAllergen,
  normaliseAllergens,
  normaliseBrand,
  parseQuantity,
} from "../product-lookup/merge.ts";

let failed = 0;
function check(name: string, ok: boolean, detail: unknown = "") {
  if (!ok) failed++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${ok ? "" : `  -> ${JSON.stringify(detail)}`}`);
}

// --- Barcodes --------------------------------------------------------------
check("Parle-G EAN-13 is valid", hasValidCheckDigit("8901719101038"));
check("wrong check digit is rejected", normaliseBarcode("8901719101039") === null);
check("letters and short codes are rejected", normaliseBarcode("12ab") === null && normaliseBarcode("1234") === null);
const upcA = normaliseBarcode("685450116442");
check("UPC-A becomes GTIN-13 with a leading zero", upcA?.gtin13 === "0685450116442", upcA);
check("UPC-A spelling kept as a variant", upcA?.variants.includes("685450116442") === true, upcA);
const indian = normaliseBarcode(" 8901719101038 ");
check("Indian EAN-13 kept as is", indian?.gtin13 === "8901719101038" && indian.variants.length === 1, indian);
check("GTIN-14 with leading zero becomes GTIN-13", normaliseBarcode("08901719101038")?.gtin13 === "8901719101038");
check("EAN-8 stays 8 digits", normaliseBarcode("96385074")?.gtin13 === "96385074");
check("UPC-E expands to UPC-A", upcEToUpcA("04252614") === "042100005264", upcEToUpcA("04252614"));
check("UPC-E scan normalises", normaliseBarcode("04252614", "upce")?.gtin13 === "0042100005264");
check("same GTIN ignores leading zeros", sameGtin("0685450116442", "685450116442"));
check("different GTINs differ", !sameGtin("8901719101038", "8901719101045"));

// --- Allergens, brands, quantities -----------------------------------------
check("OFF tag en:milk -> Milk", normaliseAllergen("en:milk") === "Milk");
check("en:gluten -> Wheat / Gluten", normaliseAllergen("en:gluten") === "Wheat / Gluten");
check("en:sesame-seeds -> Sesame", normaliseAllergen("en:sesame-seeds") === "Sesame");
check("peanut butter is Peanut, not Milk", normaliseAllergen("peanut butter") === "Peanut");
check("cocoa butter is not Milk", normaliseAllergen("cocoa butter") !== "Milk");
check("Hindi words: maida -> Wheat / Gluten", normaliseAllergen("maida") === "Wheat / Gluten");
check("duplicates removed", normaliseAllergens(["en:milk", "Milk solids", "en:gluten"]).join("|") === "Milk|Wheat / Gluten");
check("brand Parle Products -> Parle", normaliseBrand("Parle Products") === "Parle");
check("brand haldirams -> Haldiram's", normaliseBrand("haldirams") === "Haldiram's");
check("brand Nestle India Ltd -> Nestlé", normaliseBrand("Nestle India Ltd") === "Nestlé");
check("first of several brands", normaliseBrand("Britannia, Good Day") === "Britannia");
check("USDA capitals tidied", normaliseBrand("SOUNDWORKS INC") === "Soundworks Inc");
check("250 g", parseQuantity("250 g")?.amount === 250);
check("1 kg -> 1000 g", parseQuantity("1 kg")?.amount === 1000);
check("oz/g label uses grams", parseQuantity("11.93 oz/338.4 g")?.amount === 338.4);
check("1 L -> 1000 ml", parseQuantity("1 L")?.unit === "ml" && parseQuantity("1 L")?.amount === 1000);
check("similar ingredient lists agree",
  !ingredientsDiffer("Wheat flour, sugar, palm oil, milk solids", "WHEAT FLOUR, SUGAR, RBD PALM OIL, MILK SOLIDS, SALT"));
check("different ingredient lists differ",
  ingredientsDiffer("Wheat flour, sugar, palm oil", "Potato, sunflower oil, salt, spices"));

// --- Merge -----------------------------------------------------------------
const off: Candidate = {
  source: "open_food_facts", barcode: "8901719101038", name: "Parle-G Original Gluco Biscuits", brand: "Parle",
  net_quantity: "250 g", net_quantity_amount: 250,
  ingredients_text: "Wheat flour, sugar, palm oil, invert sugar syrup, milk solids, salt",
  allergens: ["Wheat / Gluten", "Milk"], may_contain: [], basis: "per_100g",
  nutrition: { calories: 454, protein_g: 6.9, carbs_g: 77.4, fat_g: 13, sugar_g: 25, sodium_mg: 290 },
};
const usdaSame: Candidate = {
  source: "usda_fdc", barcode: "8901719101038", name: "PARLE-G ORIGINAL GLUCO BISCUITS", brand: "PARLE",
  net_quantity: "8.82 oz/250 g", net_quantity_amount: 250,
  ingredients_text: "WHEAT FLOUR, SUGAR, PALM OIL, INVERT SUGAR SYRUP, MILK SOLIDS, SALT",
  basis: "per_100g", nutrition: { calories: 456, protein_g: 7.0, carbs_g: 77, fat_g: 13.2, sodium_mg: 285 },
};

const one = mergeCandidates([off]);
check("single source: name from OFF", one.fields.name?.value === "Parle-G Original Gluco Biscuits");
check("single source: OFF confidence medium", one.fields.calories?.confidence === "medium");
check("single source: no conflicts", one.conflicts.length === 0, one.conflicts);
check("unknown nutrient stays missing (never zero)", one.fields.fiber_g === undefined, one.fields.fiber_g);

const agree = mergeCandidates([off, usdaSame]);
check("nutrition prefers USDA brand-owner data", agree.fields.calories?.source === "usda_fdc" && agree.fields.calories?.value === 456);
check("agreeing sources raise confidence", agree.fields.calories?.confidence === "high", agree.fields.calories);
check("name still from OFF", agree.fields.name?.source === "open_food_facts");
check("sugar filled from OFF when USDA has none", agree.fields.sugar_g?.source === "open_food_facts");
check("no conflicts when values agree", agree.conflicts.length === 0, agree.conflicts);
check("brand normalised", agree.fields.brand?.value === "Parle");

const usdaDifferent: Candidate = {
  ...usdaSame,
  net_quantity: "100 g", net_quantity_amount: 100,
  ingredients_text: "Potato, sunflower oil, salt, spices",
  nutrition: { calories: 540, protein_g: 6.9, fat_g: 33 },
};
const clash = mergeCandidates([off, usdaDifferent]);
check("calorie clash flagged", clash.conflicts.includes("calories"), clash.conflicts);
check("conflict keeps preferred value, lists the other", clash.fields.calories?.value === 540 &&
  clash.fields.calories?.alternatives[0]?.value === 454, clash.fields.calories);
check("conflict confidence low", clash.fields.calories?.confidence === "low");
check("ingredient clash flagged, not blended", clash.conflicts.includes("ingredients_text") &&
  clash.fields.ingredients_text?.value === off.ingredients_text, clash.fields.ingredients_text);
check("pack size clash flagged", clash.conflicts.includes("net_quantity"), clash.conflicts);
check("equal protein not flagged", !clash.conflicts.includes("protein_g"));

const converted = mergeCandidates([{ ...off, converted: { calories: "1900 kJ" } }]);
check("converted value marked", converted.fields.calories?.status === "converted" &&
  converted.fields.calories?.original === "1900 kJ", converted.fields.calories);

const liquid: Candidate = { source: "nutritionix", barcode: "x", name: "Lassi", basis: "per_100ml", nutrition: { calories: 80 } };
const mixed = mergeCandidates([liquid, off]);
check("100 ml and 100 g values are never mixed", mixed.fields.basis?.value === "per_100g" &&
  mixed.fields.calories?.value === 454 && mixed.conflicts.length === 0, mixed.fields.calories);

console.log(failed === 0 ? "\nAll product-lookup tests passed." : `\n${failed} product-lookup test(s) FAILED.`);
if (failed > 0) process.exit(1);
