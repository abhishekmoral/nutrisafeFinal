"""Build assets/translations/<code>.json from keys_v1.json + tr/<code>_*.txt (lines "N|translation").
Line N translates keys_v1.json[N]. Only complete languages are written; missing ones fall back to English.
Run from anywhere: python tool/translations/build_translations.py .
Extra keys added later go in tr/<code>_extra.txt as "English key|translation".
Usage: python build_translations.py <project_root>
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = sys.argv[1]
keys = json.load(open(os.path.join(HERE, 'keys_v1.json'), encoding='utf-8'))
SKIP = {k for k in ('English', 'Hinglish', 'application/pdf') if k in keys}
LANGS = ['hi', 'hinglish', 'bn', 'ta', 'te', 'mr', 'gu', 'pa', 'ur', 'kn', 'ml']
ph = lambda t: sorted(set(re.findall(r'\{\w+\}', t)))

ok = True
for code in LANGS:
    files = sorted(glob.glob(os.path.join(HERE, 'tr', f'{code}_*.txt')))
    if not files:
        print(code, 'MISSING')
        ok = False
        continue
    out = {}
    for f in files:
        extra = f.endswith('_extra.txt')
        for n, line in enumerate(open(f, encoding='utf-8').read().split('\n'), 1):
            if not line.strip():
                continue
            if '|' not in line:
                print(code, os.path.basename(f), n, 'no separator:', line[:60])
                ok = False
                continue
            left, text = line.split('|', 1)
            text = text.strip()
            if extra:
                key = left
            else:
                try:
                    key = keys[int(left)]
                except (ValueError, IndexError):
                    print(code, os.path.basename(f), n, 'bad index', left)
                    ok = False
                    continue
            if key in out:
                print(code, 'duplicate', left)
            if ph(key) != ph(text):
                print(code, 'placeholder mismatch', left, ph(key), ph(text))
                ok = False
            out[key] = text
    missing = [i for i, k in enumerate(keys) if k not in out and k not in SKIP]
    if missing:
        print(code, 'INCOMPLETE, not written:', len(missing), 'missing, first', missing[:10])
        ok = False
        continue
    path = os.path.join(ROOT, 'assets', 'translations', f'{code}.json')
    json.dump(dict(sorted(out.items())), open(path, 'w', encoding='utf-8', newline='\n'), ensure_ascii=False, indent=1)
    print(code, len(out))
print('OK' if ok else 'PROBLEMS')
