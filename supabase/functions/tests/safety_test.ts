// Tests for the rule-based warning-sign screening used by the health-agent function.
// Run with:  node supabase/functions/tests/safety_test.ts   (Node 24+)

import { screenMessage, urgentNotice } from "../health-agent/safety.ts";

let failed = 0;

function check(name: string, ok: boolean, detail = "") {
  if (!ok) failed++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${ok || !detail ? "" : `  -> ${detail}`}`);
}

function expectFlag(text: string, level: "urgent" | "emergency", ruleId: string) {
  const result = screenMessage(text);
  check(
    `flags [${level}] ${text}`,
    result.flagged && result.level === level && result.ruleIds.includes(ruleId),
    JSON.stringify(result),
  );
}

function expectClear(text: string) {
  const result = screenMessage(text);
  check(`no flag: ${text}`, !result.flagged, JSON.stringify(result));
}

// ---- Must be flagged: English, Hinglish and Hindi ----
expectFlag("I have chest pain since morning", "emergency", "chest_pain_breathing");
expectFlag("mujhe seene me dard ho raha hai", "emergency", "chest_pain_breathing");
expectFlag("सीने में दर्द हो रहा है", "emergency", "chest_pain_breathing");
expectFlag("saans lene mein dikkat ho rahi hai", "emergency", "chest_pain_breathing");
expectFlag("I can't breathe properly", "emergency", "chest_pain_breathing");
expectFlag("I want to die", "emergency", "self_harm");
expectFlag("my throat is closing after eating peanuts", "emergency", "severe_allergic_reaction");
expectFlag("I fainted this morning", "emergency", "fainting_seizure");
expectFlag("he is having fits", "emergency", "fainting_seizure");
expectFlag("wo behosh ho gaya", "emergency", "fainting_seizure");
// The same Hindi word typed two ways: ड + nukta (two characters) and precomposed ड़ (one).
expectFlag("मुझे दौरा पड़ गया", "emergency", "fainting_seizure");
expectFlag("मुझे दौरा पड़ गया", "emergency", "fainting_seizure");
expectFlag("there is blood in my stool", "urgent", "blood_in_stool_or_vomit");
expectFlag("potty me khoon aa raha hai", "urgent", "blood_in_stool_or_vomit");
expectFlag("मल में खून आ रहा है", "urgent", "blood_in_stool_or_vomit");
expectFlag("khoon ki ulti hui", "urgent", "blood_in_stool_or_vomit");
expectFlag("I have black stools since two days", "urgent", "blood_in_stool_or_vomit");
expectFlag("I have severe stomach pain", "urgent", "severe_abdominal_pain");
expectFlag("pet me bahut dard hai", "urgent", "severe_abdominal_pain");
expectFlag("पेट में बहुत दर्द है", "urgent", "severe_abdominal_pain");
expectFlag("पेट में तेज़ दर्द है", "urgent", "severe_abdominal_pain");
expectFlag("पेट में तेज़ दर्द है", "urgent", "severe_abdominal_pain");
expectFlag("I can't pass gas since yesterday", "urgent", "cannot_pass_gas");
expectFlag("gas pass nahi ho rahi", "urgent", "cannot_pass_gas");
expectFlag("vomiting for 3 days", "urgent", "persistent_vomiting_dehydration");
expectFlag("baar baar ulti ho rahi hai", "urgent", "persistent_vomiting_dehydration");
expectFlag("my baby has a fever", "urgent", "high_fever_infant");

// An emergency rule wins over an urgent one in the same message.
const both = screenMessage("severe stomach pain and chest pain");
check("emergency outranks urgent", both.level === "emergency" && both.ruleIds.length === 2, JSON.stringify(both));

// ---- Must NOT be flagged: everyday questions ----
expectClear("Create a meal plan that fits my budget");
expectClear("I want to diet and lose weight slowly");
expectClear("Mujhe 4 din se constipation ho rahi hai.");
expectClear("I am not able to pass stool for 3 days");
expectClear("Suggest foods for better digestion");
expectClear("Analyze my daily nutrition.");
expectClear("I feel a little bloated after lunch");
expectClear("What is a good breakfast for a diabetic?");
expectClear("mild stomach ache after spicy food");
expectClear("Check my protein intake.");
expectClear("मुझे कब्ज है, क्या खाऊं?");

// ---- Fixed notices ----
check("Hindi notice is in Hindi", urgentNotice("urgent", "hi").includes("डॉक्टर"));
check("Hinglish notice", urgentNotice("emergency", "hinglish").includes("112 par call"));
check("unknown language falls back to English", urgentNotice("emergency", "ta").includes("call 112"));
check("every notice names the emergency number", ["en", "hi", "hinglish"].every((l) =>
  urgentNotice("urgent", l).includes("112") && urgentNotice("emergency", l).includes("112")));

console.log(failed === 0 ? "\nAll safety tests passed." : `\n${failed} safety test(s) FAILED.`);
if (failed > 0) process.exit(1);
