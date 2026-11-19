// Tests for the medical-report rules used by the analyze-report function.
// Run with:  node supabase/functions/tests/report_rules_test.ts   (Node 24+)

import {
  criticalRule,
  flagFor,
  parseNumeric,
  rangeFlag,
  urgentGuidance,
  validateResult,
} from "../analyze-report/rules.ts";

let failed = 0;
function check(name: string, ok: boolean, detail: unknown = "") {
  if (!ok) failed++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${ok ? "" : `  -> ${JSON.stringify(detail)}`}`);
}
function eq(name: string, actual: unknown, expected: unknown) {
  check(name, JSON.stringify(actual) === JSON.stringify(expected), { actual, expected });
}

// ---- reading numbers exactly as printed
eq("plain number", parseNumeric("180"), 180);
eq("decimal", parseNumeric(" 12.5 "), 12.5);
eq("thousands comma", parseNumeric("1,200"), 1200);
eq("lakh-style 1,50,000 is not guessed", parseNumeric("1,50,000"), null);
eq("less-than value is not a number", parseNumeric("<0.5"), null);
eq("word result", parseNumeric("Positive"), null);
eq("range text", parseNumeric("4-6"), null);
eq("empty", parseNumeric(""), null);

// ---- comparing with the lab's own range (PRD example values)
eq("B12 180 vs 200-900 is low", rangeFlag(180, 200, 900), "low");
eq("Vitamin D 18 vs 30-100 is low", rangeFlag(18, 30, 100), "low");
eq("inside range", rangeFlag(450, 200, 900), "normal");
eq("on the lower limit counts as inside", rangeFlag(200, 200, 900), "normal");
eq("above range", rangeFlag(950, 200, 900), "high");
eq("only an upper limit", rangeFlag(250, null, 200), "high");
eq("only a lower limit", rangeFlag(45, 40, null), "normal");
eq("no range printed", rangeFlag(180, null, null), "unknown");
eq("no numeric value", rangeFlag(null, 200, 900), "unknown");
eq("reversed range is not trusted", rangeFlag(5, 10, 2), "unknown");

// ---- critical rules need the right test AND the right unit
eq("very low glucose", criticalRule("Fasting Blood Glucose", 38, "mg/dL"), "glucose");
eq("very high glucose", criticalRule("Glucose, Random", 520, "mg/dl"), "glucose");
eq("glucose in mmol/L", criticalRule("Glucose", 25, "mmol/L"), "glucose");
eq("ordinary high glucose is not critical", criticalRule("Fasting Blood Glucose", 180, "mg/dL"), null);
eq("urine glucose is ignored", criticalRule("Urine Glucose", 500, "mg/dL"), null);
eq("HbA1c is not a glucose value", criticalRule("HbA1c (Glycated Hemoglobin)", 5.6, "%"), null);
eq("estimated average glucose is ignored", criticalRule("Estimated Average Glucose", 520, "mg/dL"), null);
eq("glucose without a unit is not judged", criticalRule("Glucose", 38, null), null);
eq("low hemoglobin", criticalRule("Haemoglobin", 6.2, "g/dL"), "hemoglobin");
eq("Hb with gm/dl", criticalRule("Hb", 6.5, "gm/dl"), "hemoglobin");
eq("mild low hemoglobin is not critical", criticalRule("Hemoglobin", 10.5, "g/dL"), null);
eq("MCH is not hemoglobin", criticalRule("MCH (Mean Corpuscular Hb)", 6, "pg"), null);
eq("MCHC in g/dL is not hemoglobin", criticalRule("MCHC", 31, "g/dL"), null);
eq("high potassium", criticalRule("Serum Potassium", 6.8, "mmol/L"), "potassium");
eq("normal potassium", criticalRule("Potassium", 4.2, "mEq/L"), null);
eq("low sodium", criticalRule("Sodium", 115, "mmol/L"), "sodium");
eq("unrelated test", criticalRule("Vitamin B12", 180, "pg/mL"), null);

// ---- combined flag
eq("critical wins over the range flag",
  flagFor({ test_name: "Hemoglobin", value_numeric: 6, unit: "g/dL", reference_low: 13, reference_high: 17 }),
  { flag: "critical", rule: "hemoglobin" });
eq("range flag when nothing is critical",
  flagFor({ test_name: "Vitamin B12", value_numeric: 180, unit: "pg/mL", reference_low: 200, reference_high: 900 }),
  { flag: "low", rule: null });

// ---- validating what the model read
eq("the number is taken from the printed text, not from the model",
  validateResult({ test_name: "TSH", value_text: "<0.01", value_numeric: 0.01, unit: "uIU/mL", reference_low: 0.4, reference_high: 4, reference_text: "0.4 - 4.0" }),
  { test_name: "TSH", value_text: "<0.01", value_numeric: null, unit: "uIU/mL", reference_low: 0.4, reference_high: 4, reference_text: "0.4 - 4.0" });
eq("a model number that disagrees with the text is replaced",
  validateResult({ test_name: "B12", value_text: "180", value_numeric: 810, unit: "pg/mL", reference_low: null, reference_high: null, reference_text: null })?.value_numeric,
  180);
eq("missing value is rejected", validateResult({ test_name: "B12", value_text: "  " }), null);
eq("missing name is rejected", validateResult({ value_text: "12" }), null);
eq("non-object is rejected", validateResult("B12 180"), null);
eq("bad range numbers are dropped",
  validateResult({ test_name: "X", value_text: "1", reference_low: "abc", reference_high: Infinity })?.reference_high,
  null);

// ---- fixed guidance
check("urgent guidance names 112 in every language", ["en", "hi", "hinglish", "ta"].every((l) => urgentGuidance(l).includes("112")));
check("Hindi guidance is in Hindi", urgentGuidance("hi").includes("डॉक्टर"));

console.log(failed === 0 ? "\nAll report-rule tests passed." : `\n${failed} report-rule test(s) FAILED.`);
if (failed > 0) process.exit(1);
