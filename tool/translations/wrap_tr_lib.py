"""Wrap user-facing Dart string literals with .tr / .trf({...}).

Usage: python wrap_tr.py <project_root> [--dry]
Writes report.json next to this script: keys, skipped literals with letters (for manual review),
and wraps that sit inside top-level / static declarations (would not re-translate).
"""
import json
import os
import re
import sys

ROOT = None

HERE = os.path.dirname(os.path.abspath(__file__))

SKIP_FILES = {
    'lib/utils/constants/enums.dart',
    'lib/utils/constants/api_constants.dart',
    'lib/utils/constants/text_strings.dart',
    'lib/utils/localization/translations.dart',
    'lib/utils/localization/language_helper.dart',
    'lib/utils/logging/logger.dart',
    'lib/main.dart',
}
SKIP_CALLS = {
    'from', 'select', 'eq', 'neq', 'rpc', 'order', 'inFilter', 'isFilter', 'ilike', 'like', 'or',
    'update', 'insert', 'upsert', 'delete', 'filter', 'match', 'gte', 'lte', 'gt', 'lt', 'not',
    'channel', 'invoke', 'upload', 'uploadBinary', 'createSignedUrl', 'download', 'remove', 'textSearch',
    'DateFormat', 'RegExp', 'Uri', 'parse', 'tryParse', 'loadString', 'read', 'write', 'Key',
    'ValueKey', 'debugPrint', 'print', 'info', 'warning', 'error', 'debug', 'split', 'join',
    'replaceAll', 'startsWith', 'endsWith', 'contains', 'indexOf', 'substring', 'padLeft', 'asset',
    'network', 'fromCode', 'fromValue', 'containsKey', 'trParams', 'tr', 'trf', 'jsonDecode',
    'setData', 'ClipboardData', 'launchUrl', 'parseDate', 'getFormattedDate', 'readData', 'saveData',
    'Locale', 'range', 'limit', 'single', 'maybeSingle', 'storage', 'bucket', 'onPostgresChanges',
    'containsValue', 'firstWhere', 'where', 'add', 'remove', 'toSet', 'StateError', 'ArgumentError',
    'UnimplementedError', 'AssertionError', 'assert', 'Exception', 'FormatException',
}
SKIP_NAMED = {
    'format', 'tag', 'heroTag', 'pattern', 'locale', 'fontFamily', 'value', 'code', 'table', 'schema',
    'column', 'event', 'bucket', 'path', 'mimeType', 'contentType', 'model', 'role', 'status', 'scope',
    'type', 'category', 'id', 'key', 'restorationId', 'mode', 'source', 'language', 'unit', 'name',
    'childId', 'ownerId', 'userId', 'context_type', 'contextType', 'allergen', 'food', 'kind',
    'storagePath', 'fileName', 'fileType', 'decimals',
}
UNITS = {'g', 'mg', 'ml', 'kcal', 'kg', 'cm', 'mcg', 'l', 'µg', 'ug', 'iu', 'IU', 'x', 'h', 'm', 'min'}
NAME_MAP = {'getFormattedDate': 'date', 'formatNumber': 'value', 'dayLabel': 'day', 'length': 'count',
            'toString': 'value', 'toStringAsFixed': 'value', 'round': 'value', 'toInt': 'value',
            'label': 'label', 'tr': 'text'}


class Lit:
    def __init__(self, start, end, quote, raw, parts, stack):
        self.start, self.end, self.quote, self.raw = start, end, quote, raw
        self.parts = parts  # list of ('t', source_text) | ('e', expr_source, is_braced)
        self.stack = stack  # bracket stack at literal start: list of (char, name)


def scan_interpolation(src, i):
    """src[i] == '{' after '$'. Return index after matching '}'. Skips nested strings."""
    depth = 0
    n = len(src)
    while i < n:
        c = src[i]
        if c in '\'"':
            j, _ = read_string(src, i, collect=False)
            i = j
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError('unterminated interpolation')


def read_string(src, i, collect=True):
    """src[i] is a quote (optionally after r). Return (end_index, (quote, raw, parts))."""
    raw = False
    if src[i] in 'rR':
        raw = True
        i += 1
    q = src[i]
    triple = src[i:i + 3] == q * 3
    quote = q * 3 if triple else q
    i += len(quote)
    parts = []
    buf = []
    n = len(src)
    while i < n:
        if src.startswith(quote, i):
            if buf:
                parts.append(('t', ''.join(buf)))
            return i + len(quote), (quote, raw, parts)
        c = src[i]
        if c == '\\' and not raw:
            buf.append(src[i:i + 2])
            i += 2
            continue
        if c == '$' and not raw:
            if i + 1 < n and src[i + 1] == '{':
                j = scan_interpolation(src, i + 1)
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', src[i + 2:j - 1], True))
                i = j
                continue
            m = re.match(r'[A-Za-z_][A-Za-z0-9_]*', src[i + 1:])
            if m:
                if buf:
                    parts.append(('t', ''.join(buf)))
                    buf = []
                parts.append(('e', m.group(0), False))
                i += 1 + len(m.group(0))
                continue
        buf.append(c)
        i += 1
    raise ValueError('unterminated string')


def tokenize(src):
    """Return list of Lit with bracket stack info."""
    lits = []
    stack = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j == -1 else j
            continue
        if src.startswith('/*', i):
            j = src.find('*/', i + 2)
            i = n if j == -1 else j + 2
            continue
        if c in '\'"' or (c in 'rR' and i + 1 < n and src[i + 1] in '\'"' and not (i > 0 and (src[i - 1].isalnum() or src[i - 1] == '_'))):
            start = i
            j, (quote, raw, parts) = read_string(src, i)
            lits.append(Lit(start, j, quote, raw, parts, list(stack)))
            i = j
            continue
        if c in '([{':
            m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*(<[^<>()]*>)?\s*$', src[max(0, i - 80):i])
            stack.append((c, m.group(1) if (m and c == '(') else ''))
        elif c in ')]}':
            if stack:
                stack.pop()
        i += 1
    return lits


ESC = {'n': '\n', 't': '\t', 'r': '\r', "'": "'", '"': '"', '\\': '\\', '$': '$', 'b': '\b', 'f': '\f', 'v': '\v'}


def unescape(text):
    out = []
    i = 0
    while i < len(text):
        c = text[i]
        if c == '\\' and i + 1 < len(text):
            d = text[i + 1]
            if d == 'u':
                if text[i + 2] == '{':
                    k = text.index('}', i)
                    out.append(chr(int(text[i + 3:k], 16)))
                    i = k + 1
                else:
                    out.append(chr(int(text[i + 2:i + 6], 16)))
                    i += 6
                continue
            out.append(ESC.get(d, d))
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def dart_quote(value):
    v = value.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n')
    return "'" + v + "'"


def param_name(expr):
    e = expr.strip().rstrip('!?')
    # drop parenthesised arguments
    prev = None
    while prev != e:
        prev = e
        e = re.sub(r'\([^()]*\)', '', e)
    idents = re.findall(r'[A-Za-z_][A-Za-z0-9_]*', e)
    if not idents:
        return 'value'
    name = idents[-1]
    if name in NAME_MAP:
        return NAME_MAP[name]
    if name.startswith('_'):
        name = name.lstrip('_') or 'value'
    return name


def line_of(src, pos):
    return src.count('\n', 0, pos) + 1


def prev_token(src, pos):
    k = pos - 1
    while k >= 0 and src[k] in ' \t\r\n':
        k -= 1
    return k


def next_token(src, pos):
    k = pos
    while k < len(src) and src[k] in ' \t\r\n':
        k += 1
    return k


def decl_context(src, pos):
    """The nearest preceding line with indent <= 2 (a member/top-level declaration)."""
    lines = src[:pos].split('\n')
    for line in reversed(lines):
        if not line.strip() or line.strip().startswith('//') or line.strip().startswith('*') or line.strip().startswith('/'):
            continue
        indent = len(line) - len(line.lstrip(' '))
        if indent <= 2:
            return line.strip()
    return ''


def process(path, rel, report):
    src = open(path, encoding='utf-8').read()
    lits = tokenize(src)
    # group adjacent literals
    groups = []
    for lit in lits:
        if groups and src[groups[-1][-1].end:lit.start].strip() == '' and groups[-1][-1].stack == lit.stack:
            groups[-1].append(lit)
        else:
            groups.append([lit])

    edits = []
    for g in groups:
        start, end = g[0].start, g[-1].end
        line_no = line_of(src, start)
        line_start = src.rfind('\n', 0, start) + 1
        line_text = src[line_start:src.find('\n', start) if src.find('\n', start) != -1 else len(src)]
        stripped = line_text.strip()
        if re.match(r'(import|export|part|library)\b', stripped) or stripped.startswith('@'):
            continue
        if any(l.raw for l in g):
            continue
        # text outside interpolations
        text = ''.join(unescape(p[1]) for l in g for p in l.parts if p[0] == 't')
        letters = re.findall(r'[A-Za-z]+', text)
        if not letters:
            continue
        words = [w for w in letters if w not in UNITS]

        def skip(reason):
            report['skipped'].append({'file': rel, 'line': line_no, 'reason': reason, 'text': src[start:end][:160]})

        pk = prev_token(src, start)
        nk = next_token(src, end)
        before = src[max(0, pk - 12):pk + 1]
        after = src[nk:nk + 6]
        if after.startswith('.tr'):
            continue
        if src[pk] == '[' and src[nk:nk + 1] == ']':
            continue
        if src[nk:nk + 1] == ':' and src[pk] in '{,':
            continue
        if re.search(r'(==|!=)$', before) or re.search(r'\bcase$', before) or after.startswith(('==', '=>', '!=')):
            continue
        if src[pk] == '|' or after.startswith('||'):
            continue
        m = re.search(r'([A-Za-z_][A-Za-z0-9_]*)\s*:$', src[max(0, pk - 40):pk + 1])
        if m and m.group(1) in SKIP_NAMED:
            continue
        call = g[0].stack[-1][1] if g[0].stack and g[0].stack[-1][0] == '(' else ''
        if call in SKIP_CALLS:
            continue
        if re.search(r'\bthrow\s*$', src[max(0, pk - 8):pk + 1]) is None and rel.startswith('lib/data/'):
            continue
        if '://' in text or re.search(r'\.(pdf|png|jpe?g|json|svg)\b', text) or re.fullmatch(r'[\w\-]+/[\w\-.+/]+', text.strip()):
            continue
        t = text.strip()
        if re.fullmatch(r"[dMyEHhmsa ,.:/'\-]+", t):
            continue  # date formats such as 'dd MMM yyyy'
        ctx0 = decl_context(src, start)
        ctx0 = ctx0.replace('\x08', '')
        if re.match(r'(static\s+)?const\b', ctx0) or re.match(r'enum\b', ctx0) or re.match(r'const\s+[A-Z]\w*\s*\(', ctx0):
            report['const_decl'].append({'file': rel, 'line': line_no, 'decl': ctx0[:80], 'text': t[:80]})
            continue
        if not words:
            continue
        if re.fullmatch(r'[a-z0-9_.\-]+', t):
            continue  # identifiers, codes, single lower-case words
        if re.fullmatch(r'[A-Z0-9_\-]+', t):
            continue  # DELETE, NS-, codes
        if re.fullmatch(r'[^A-Za-z]*[a-z][a-z0-9_]*[^A-Za-z]*', t) and len(words) == 1:
            continue
        # interpolations
        exprs = [p for l in g for p in l.parts if p[0] == 'e']
        bad = [p for p in exprs if re.search(r'[\'"?]|==|!=|&&|\|\|', p[1].replace('?.', '.').rstrip('!?') if not p[1].strip().endswith('?') else p[1])]
        bad = [p for p in exprs if re.search(r"['\"]|\s\?\s|==|!=|&&|\|\||\?\?", p[1])]
        if bad:
            skip('complex interpolation')
            continue
        names = {}
        params = []
        key_parts = []
        for l in g:
            for p in l.parts:
                if p[0] == 't':
                    key_parts.append(unescape(p[1]))
                else:
                    expr = p[1].strip()
                    if expr in names:
                        nm = names[expr]
                    else:
                        base = param_name(expr)
                        nm = base
                        k = 2
                        while nm in names.values():
                            nm = f'{base}{k}'
                            k += 1
                        names[expr] = nm
                        params.append((nm, expr))
                    key_parts.append('{' + nm + '}')
        key = ''.join(key_parts)
        if params:
            args = ', '.join(f"'{nm}': {expr}" for nm, expr in params)
            replacement = f"{dart_quote(key)}.trf({{{args}}})"
        else:
            replacement = f"{dart_quote(key)}.tr"
        edits.append((start, end, replacement))
        report['keys'].setdefault(key, []).append(f'{rel}:{line_no}')
        ctx = decl_context(src, start)
        if re.match(r'(static\s+)?(const|final)\b', ctx) or re.match(r'(const|final)\s', ctx):
            report['in_declarations'].append({'file': rel, 'line': line_no, 'decl': ctx[:100], 'key': key})

    if not edits:
        return False
    new = src
    for s, e, r in sorted(edits, reverse=True):
        new = new[:s] + r + new[e:]
    uses_trf = '.trf(' in new and 'localization/translations.dart' not in new
    uses_tr = True
    # imports
    imports = []
    if "import 'package:get/get.dart';" not in new:
        imports.append("import 'package:get/get.dart';")
    if uses_trf:
        depth = rel.count('/') - 1  # lib/a/b.dart -> 1
        prefix = '../' * depth
        imports.append(f"import '{prefix}utils/localization/translations.dart';")
    if imports:
        m = list(re.finditer(r"^import [^\n]+;\n", new, re.M))
        pos = m[-1].end() if m else 0
        new = new[:pos] + '\n'.join(imports) + '\n' + new[pos:]
    report['files'].append(rel)
    if not DRY:
        open(path, 'w', encoding='utf-8', newline='\n').write(new)
    return True


