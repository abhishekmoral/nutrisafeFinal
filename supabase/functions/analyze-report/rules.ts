// Rules for medical report values. These run in code, not in the language model:
// the model only reads what is printed; comparing and flagging happens here.
//
// IMPORTANT: the CRITICAL_RULES thresholds are a small starter list based on commonly published
// laboratory "critical value" ranges. They must be reviewed and extended by a clinician before
// the app is released. A value that matches no rule is NOT thereby declared safe.

export type Flag = "low" | "high" | "normal" | "critical" | "unknown";

/** A plain printed number ("180", "12.5", "1,200") or null for anything else ("<0.5", "Positive"). */
export function parseNumeric(text: string): number | null {
  const cleaned = text.trim().replace(/(\d),(?=\d{3}\b)/g, "$1");
  if (!/^[+-]?\d+(\.\d+)?$/.test(cleaned)) return null;
  const value = Number(cleaned);
  return Number.isFinite(value) ? value : null;
}

/** Compares a value with the range printed by the laboratory on the same report. */
export function rangeFlag(value: number | null, low: number | null, high: number | null): Flag {
  if (value === null || (low === null && high === null)) return "unknown";
  if (low !== null && high !== null && low > high) return "unknown";
  if (low !== null && value < low) return "low";
  if (high !== null && value > high) return "high";
  return "normal";
}

function normaliseUnit(unit: string | null): string {
  return (unit ?? "").toLowerCase().replace(/\s+/g, "").replace(/gms?\//, "g/").replace(/dl$/, "dl");
}

interface CriticalRule {
  id: string;
  name: RegExp;
  exclude?: RegExp;
  units: { unit: RegExp; low?: number; high?: number }[];
}

const CRITICAL_RULES: CriticalRule[] = [
  {
    id: "glucose",
    name: /\b(glucose|blood sugar|fbs|rbs|ppbs)\b/i,
    exclude: /urine|hba1c|a1c|glycated|glycosylated|average|estimated/i,
    units: [
      { unit: /^mg\/dl$/, low: 50, high: 400 },
      { unit: /^mmol\/l$/, low: 2.8, high: 22.2 },
    ],
  },
  {
    id: "potassium",
    name: /\bpotassium\b/i,
    exclude: /urine/i,
    units: [{ unit: /^(mmol|meq)\/l$/, low: 2.8, high: 6.2 }],
  },
  {
    id: "sodium",
    name: /\bsodium\b/i,
    exclude: /urine/i,
    units: [{ unit: /^(mmol|meq)\/l$/, low: 120, high: 160 }],
  },
  {
    id: "hemoglobin",
    name: /\b(ha?emoglobin|hb)\b/i,
    exclude: /hba1c|a1c|glycated|glycosylated|mch|mean|electrophoresis|hb\s?[afs]\d?\b|fetal|foetal/i,
    units: [
      { unit: /^(g\/dl|g%)$/, low: 7, high: 20 },
      { unit: /^g\/l$/, low: 70, high: 200 },
    ],
  },
];

/** The id of the critical rule a value breaks, or null. Needs a matching unit to apply. */
export function criticalRule(testName: string, value: number | null, unit: string | null): string | null {
  if (value === null) return null;
  const u = normaliseUnit(unit);
  for (const rule of CRITICAL_RULES) {
    if (!rule.name.test(testName) || (rule.exclude && rule.exclude.test(testName))) continue;
    const limits = rule.units.find((x) => x.unit.test(u));
    if (!limits) continue;
    if ((limits.low !== undefined && value < limits.low) || (limits.high !== undefined && value > limits.high)) {
      return rule.id;
    }
  }
  return null;
}

export interface ReadResult {
  test_name: string;
  value_text: string;
  value_numeric: number | null;
  unit: string | null;
  reference_low: number | null;
  reference_high: number | null;
  reference_text: string | null;
}

function text(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, max) : null;
}

function finite(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

/**
 * Checks one result read by the model. Returns null when it is unusable.
 * The number is always taken from the printed text: if the text is not a plain number,
 * no numeric value is kept, whatever the model returned.
 */
export function validateResult(raw: unknown): ReadResult | null {
  if (typeof raw !== "object" || raw === null) return null;
  const r = raw as Record<string, unknown>;
  const testName = text(r.test_name, 120);
  const valueText = text(r.value_text, 60);
  if (!testName || !valueText) return null;
  return {
    test_name: testName,
    value_text: valueText,
    value_numeric: parseNumeric(valueText),
    unit: text(r.unit, 30),
    reference_low: finite(r.reference_low),
    reference_high: finite(r.reference_high),
    reference_text: text(r.reference_text, 120),
  };
}

/** Flag for a result: a broken critical rule wins, otherwise the lab-range comparison. */
export function flagFor(r: Pick<ReadResult, "test_name" | "value_numeric" | "unit" | "reference_low" | "reference_high">): {
  flag: Flag;
  rule: string | null;
} {
  const rule = criticalRule(r.test_name, r.value_numeric, r.unit);
  if (rule) return { flag: "critical", rule };
  return { flag: rangeFlag(r.value_numeric, r.reference_low, r.reference_high), rule: null };
}

// Fixed, pre-written guidance (never generated). 112 is India's emergency number.
const URGENT: Record<string, string> = {
  en: "⚠️ At least one value on this report is in a range that laboratories usually report to a doctor straight away. Please contact a doctor or go to a hospital today, and take this report with you. If you feel very unwell, call 112.",
  hi: "⚠️ इस रिपोर्ट का कम से कम एक मान ऐसी सीमा में है जिसकी सूचना लैब आमतौर पर तुरंत डॉक्टर को देती है। कृपया आज ही डॉक्टर से संपर्क करें या अस्पताल जाएँ, और यह रिपोर्ट साथ ले जाएँ। तबीयत बहुत खराब लगे तो 112 पर कॉल करें।",
  hinglish: "⚠️ Is report ki kam se kam ek value aisi range mein hai jiski jaankari lab aam taur par turant doctor ko deti hai. Kripya aaj hi doctor se sampark karein ya hospital jaayein, aur yeh report saath le jaayein. Tabiyat bahut kharab lage to 112 par call karein.",
};

export function urgentGuidance(language: string): string {
  return URGENT[language] ?? URGENT.en;
}
