# App translations (work in progress)

The app's English texts are the translation keys (`'Save'.tr`, `'Added to {label}'.trf({...})`).
`lib/utils/localization/translations.dart` loads `assets/translations/<code>.json` at start-up.
A language without a JSON file shows English.

## Status (2026-11-15)

| Done (in assets) | Not done |
|---|---|
| hi, hinglish, bn, ta, te, mr, gu | pa (lines 0–360 written in `tr/pa_1.txt`, 361–720 missing), ur, kn, ml |

## How to continue

1. `keys_v1.json` is the frozen list of 721 English texts. Line `N|text` in `tr/<code>_*.txt` translates entry `N`.
   Entries 210, 287 and 684 (English, Hinglish, application/pdf) need no translation.
2. Keep every `{placeholder}`, `DELETE`, `NS-84K92P`, units (g, mg, ml, kcal) and `112` exactly as they are.
3. Build and check: `python tool/translations/build_translations.py .`
   It writes only complete languages and reports any missing line or placeholder mismatch.
4. Texts added to the app after `keys_v1.json` go in `tr/<code>_extra.txt` as `English text|translation`.
   `python tool/translations/extract_keys.py .` lists every key the app uses now (writes `keys.json` here).
