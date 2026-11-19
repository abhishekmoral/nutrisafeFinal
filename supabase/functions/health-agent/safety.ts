// Rule-based warning-sign screening. It is deliberately independent of the language model:
// if a rule matches, the urgent notice is added to the reply no matter what the model wrote.
//
// IMPORTANT: this keyword list is a starting point written by engineers. It must be reviewed
// and extended by a clinician, and by native speakers of each supported language, before the
// app is released. Regional-script coverage is currently Hindi only.

export type SafetyLevel = "urgent" | "emergency";

interface Rule {
  id: string;
  level: SafetyLevel;
  patterns: RegExp[];
}

const RAW_RULES: Rule[] = [
  {
    id: "self_harm",
    level: "emergency",
    patterns: [
      /\b(kill myself|suicid\w*|end my life|want to die|self[- ]harm)\b/i,
      /\b(mar jana chahta|mar jana chahti|jeena nahi chahta|jeena nahi chahti|khudkushi|atmahatya)\b/i,
      /(आत्महत्या|मर जाना चाहत|जीना नहीं चाहत)/,
    ],
  },
  {
    id: "chest_pain_breathing",
    level: "emergency",
    patterns: [
      /\b(chest pain|chest tightness|can'?t breathe|cannot breathe|difficulty breathing|trouble breathing|short(ness)? of breath)\b/i,
      /\b(seene? me(in)? dard|chhati me(in)? dard|saans nahi|saans lene me(in)? (dikkat|taklif|problem))\b/i,
      /(सीने में दर्द|छाती में दर्द|सांस नहीं|साँस नहीं|सांस लेने में)/,
    ],
  },
  {
    id: "severe_allergic_reaction",
    level: "emergency",
    patterns: [
      /\b(throat (is )?(closing|swelling|swollen)|swollen (tongue|lips|face)|anaphyla\w*)\b/i,
      /\b(gala (band|sooj)|hont sooj|jeebh sooj|chehra sooj)\w*/i,
      /(गला बंद|गला सूज|होंठ सूज|जीभ सूज)/,
    ],
  },
  {
    id: "fainting_seizure",
    level: "emergency",
    patterns: [
      // "fits" alone is not matched: "a plan that fits my budget" is not a symptom.
      /\b(faint(ed|ing)?|passed out|unconscious|seizures?|convulsions?|(having|had|getting|got) (a )?fits?)\b/i,
      /\b(behosh|behoshi|daura pad|daure pad|mirgi)\w*/i,
      /(बेहोश|दौरा पड़|दौरे पड़|मिर्गी)/,
    ],
  },
  {
    id: "blood_in_stool_or_vomit",
    level: "urgent",
    patterns: [
      /\b(blood in (my |the )?(stool|poop|potty|vomit|urine)|bloody (stool|vomit|diarrh\w*)|black (tarry )?stools?|vomit(ing|ed)? blood)\b/i,
      /\b((potty|latrine|stool|mal|ulti|peshab) me(in)? (khoon|blood)|khoon ki ulti|kala (mal|stool|potty))\b/i,
      /(मल में खून|पॉटी में खून|उल्टी में खून|खून की उल्टी|पेशाब में खून)/,
    ],
  },
  {
    id: "severe_abdominal_pain",
    level: "urgent",
    patterns: [
      /\b(severe|unbearable|worst|intense|sharp) (abdominal|stomach|belly|tummy) (pain|ache|cramps?)\b/i,
      /\b(pet me(in)? (bahut|tez|bohot|bht|asahniya) (zyada )?dard|bahut tez pet dard)\b/i,
      /(पेट में (बहुत|तेज|तेज़) दर्द)/,
    ],
  },
  {
    id: "cannot_pass_gas",
    level: "urgent",
    patterns: [
      // Gas / wind only. Not passing stool on its own is ordinary constipation and is
      // handled by the agent's follow-up questions, not by this urgent rule.
      /\b(can'?t|cannot|unable to|not able to) pass (gas|wind)\b/i,
      /\bgas (pass )?nahi (ho|nikal)\w*/i,
      /(गैस (पास )?नहीं)/,
    ],
  },
  {
    id: "persistent_vomiting_dehydration",
    level: "urgent",
    patterns: [
      /\b(vomiting (all day|for \d+ days|non[- ]?stop|continuously|repeatedly)|can'?t keep (anything|water|food) down|not urinat\w*)/i,
      /\b(lagatar ulti|baar baar ulti|ulti ruk nahi)\w*/i,
      /(लगातार उल्टी|बार बार उल्टी|बार-बार उल्टी)/,
    ],
  },
  {
    id: "high_fever_infant",
    level: "urgent",
    patterns: [
      /\b(fever (of|above|over) 10[3-9]|high fever for \d+ days|baby .* (fever|not feeding)|infant .* (fever|not feeding))\b/i,
    ],
  },
];

// Patterns and input are both Unicode-normalised (NFC), so a letter typed with a separate
// nukta mark and the same letter typed as one precomposed character match the same rule.
const RULES: Rule[] = RAW_RULES.map((rule) => ({
  ...rule,
  patterns: rule.patterns.map((p) => new RegExp(p.source.normalize("NFC"), p.flags)),
}));

export function screenMessage(text: string): { flagged: boolean; level: SafetyLevel; ruleIds: string[] } {
  const normalized = text.normalize("NFC");
  const hits = RULES.filter((rule) => rule.patterns.some((p) => p.test(normalized)));
  const level: SafetyLevel = hits.some((h) => h.level === "emergency") ? "emergency" : "urgent";
  return { flagged: hits.length > 0, level, ruleIds: hits.map((h) => h.id) };
}

// Fixed, pre-written notices (never generated). 112 is India's emergency number.
const NOTICES: Record<SafetyLevel, Record<string, string>> = {
  emergency: {
    en: "⚠️ What you describe can be an emergency. Please call 112 or go to the nearest hospital now. Do not wait for advice from this app.",
    hi: "⚠️ आपने जो बताया वह आपात स्थिति हो सकती है। कृपया अभी 112 पर कॉल करें या नज़दीकी अस्पताल जाएँ। इस ऐप की सलाह का इंतज़ार न करें।",
    hinglish: "⚠️ Aapne jo bataya woh emergency ho sakti hai. Kripya abhi 112 par call karein ya nazdeeki hospital jaayein. Is app ki salah ka intezaar na karein.",
  },
  urgent: {
    en: "⚠️ These can be warning signs that need a doctor. Please see a doctor today. If it gets worse, call 112 or go to a hospital.",
    hi: "⚠️ ये ऐसे लक्षण हो सकते हैं जिनके लिए डॉक्टर को दिखाना ज़रूरी है। कृपया आज ही डॉक्टर से मिलें। हालत बिगड़े तो 112 पर कॉल करें या अस्पताल जाएँ।",
    hinglish: "⚠️ Yeh aise warning signs ho sakte hain jinke liye doctor ko dikhana zaroori hai. Kripya aaj hi doctor se milein. Halat bigde to 112 par call karein ya hospital jaayein.",
  },
};

export function urgentNotice(level: SafetyLevel, language: string): string {
  const set = NOTICES[level];
  // Languages without a reviewed translation get the English notice (the model's own reply
  // is still in the user's language).
  return set[language] ?? set.en;
}
