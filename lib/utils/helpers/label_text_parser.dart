import 'allergen_words.dart';

/// One recognised word with its position on the photo (pixels).
class OcrWord {
  const OcrWord(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;
}

/// One recognised line, in the reading order the OCR engine returned.
class OcrLine {
  const OcrLine(this.text, this.words);

  final String text;
  final List<OcrWord> words;

  double get height => words.isEmpty ? 0 : words.map((w) => w.height).reduce((a, b) => a > b ? a : b);
}

/// The text of one label photo.
class OcrPage {
  const OcrPage(this.lines);

  final List<OcrLine> lines;

  String get text => lines.map((l) => l.text).join('\n');
}

/// What could be read from the label photos. A value that was not found stays null/empty;
/// nothing is guessed or filled in from other products.
class LabelReadResult {
  String? name; // largest text on the first photo: only a suggestion
  String? brand;
  String? netQuantity;
  double? servingSize;
  String? servingUnit; // g | ml
  String? ingredientsText;
  List<String> allergens = [];
  List<String> mayContain = [];
  String? containsStatement;
  String? mayContainStatement;
  String? basis; // per_100g | per_100ml | per_serving
  bool basisFromHeader = false; // false = the table header was not read; basis is a guess
  final Map<String, double> nutrition = {};
  final Map<String, String> originals = {}; // field -> the label text it was read from
  final Set<String> converted = {}; // fields we converted (kJ -> kcal, salt -> sodium, g -> mg)
  String fullText = '';

  bool get isEmpty =>
      name == null &&
      brand == null &&
      netQuantity == null &&
      servingSize == null &&
      ingredientsText == null &&
      allergens.isEmpty &&
      mayContain.isEmpty &&
      nutrition.isEmpty;
}

/// -- Reads product details from the text of package-label photos (rules only, no AI).
/// Written for Indian FSSAI labels ("Nutritional Information per 100 g / per serve",
/// "Net Qty", "Allergen information: Contains ...") and works for most English labels.
class XLabelTextParser {
  XLabelTextParser._();

  /// Brands printed on Indian packs, and the name to show.
  static final List<(String, RegExp)> _brands = [
    ('Parle', RegExp(r'\bparle\b', caseSensitive: false)),
    ('Britannia', RegExp(r'\bbritannia\b', caseSensitive: false)),
    ('Amul', RegExp(r'\bamul\b', caseSensitive: false)),
    ('Sunfeast', RegExp(r'\bsunfeast\b', caseSensitive: false)),
    ('Aashirvaad', RegExp(r'\baashirvaad\b', caseSensitive: false)),
    ('Bingo!', RegExp(r'\bbingo\b', caseSensitive: false)),
    ('ITC', RegExp(r'\bITC\b')),
    ("Haldiram's", RegExp(r"\bhaldiram'?s?\b", caseSensitive: false)),
    ('Maggi', RegExp(r'\bmaggi\b', caseSensitive: false)),
    ('Nestlé', RegExp(r'\bnestl[eé]\b', caseSensitive: false)),
    ('Patanjali', RegExp(r'\bpatanjali\b', caseSensitive: false)),
    ('Bikaji', RegExp(r'\bbikaji\b', caseSensitive: false)),
    ('Tata Sampann', RegExp(r'\btata sampann\b', caseSensitive: false)),
    ('Tata', RegExp(r'\btata\b', caseSensitive: false)),
    ('Mother Dairy', RegExp(r'\bmother dairy\b', caseSensitive: false)),
    ('Dabur', RegExp(r'\bdabur\b', caseSensitive: false)),
    ('MTR', RegExp(r'\bMTR\b')),
    ('Lijjat', RegExp(r'\blijjat\b', caseSensitive: false)),
  ];

  /// Words that end the ingredient list.
  static final _ingredientsEnd = RegExp(
    r'(allergen|(?<!may )\bcontains?\s*:|may\s+contain|traces?\s+of|nutrition(al)?\s*(information|facts|value)|'
    r'best\s+before|use\s+by|\bmfd\b|manufactured|marketed|packed\s+(by|on)|\bnet\s*(wt|weight|qty|quantity|content)|'
    r'storage|store\s+in|\bfssai\b|\bmrp\b|customer\s+care|batch\s+no|lot\s+no|serving\s+size|per\s+100\s*(g|ml))',
    caseSensitive: false,
  );

  static LabelReadResult parse(List<OcrPage> pages) {
    final result = LabelReadResult();
    final text = pages.map((p) => p.text).join('\n');
    result.fullText = text;
    // One line of running text: hyphenated line breaks joined, spaces collapsed.
    final flat = text.replaceAll(RegExp(r'-\s*\n\s*'), '').replaceAll(RegExp(r'\s+'), ' ');

    _readIngredients(flat, result);
    _readAllergenStatements(flat, result);
    _readQuantities(flat, result);
    _readBrand(flat, result);
    if (pages.isNotEmpty) _readName(pages.first, result);
    for (final page in pages) {
      _readNutritionTable(page, result);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  static void _readIngredients(String flat, LabelReadResult result) {
    final start = RegExp(r'\bingredients?\s*[:\-–]?\s*', caseSensitive: false).firstMatch(flat);
    if (start == null) return;
    var rest = flat.substring(start.end);
    final end = _ingredientsEnd.firstMatch(rest);
    if (end != null) rest = rest.substring(0, end.start);
    rest = rest.trim().replaceAll(RegExp(r'[\s,;:.]+$'), '');
    if (rest.length < 3) return;
    if (rest.length > 1500) rest = rest.substring(0, 1500);
    result.ingredientsText = rest;
    result.originals['ingredients_text'] = rest;
  }

  static void _readAllergenStatements(String flat, LabelReadResult result) {
    // "May contain ...", "May contain traces of ...", "Made in a facility that also processes ..."
    final mayContain = RegExp(
      r'(may\s+contain(\s+traces\s+of)?|traces?\s+of|(processed|manufactured|made|packed)\s+in\s+a\s+(facility|plant|unit)[^.]{0,40}?(handles?|process(es)?|uses?))\s*:?\s*([^.]{1,200})',
      caseSensitive: false,
    );
    final mayContainFound = <String>[];
    final statements = <String>[];
    for (final m in mayContain.allMatches(flat)) {
      final found = XAllergenWords.find(m.group(7) ?? '');
      if (found.isEmpty) continue;
      statements.add(m.group(0)!.trim());
      for (final a in found) {
        if (!mayContainFound.contains(a)) mayContainFound.add(a);
      }
    }

    // "Contains: wheat, milk" / "Allergen information: Contains wheat and milk".
    // ("Contains added flavours" names no allergen and is ignored.)
    final contains = RegExp(r'(?<!may\s)\bcontains?\b\s*:?\s*([^.]{1,200})', caseSensitive: false);
    final containsFound = <String>[];
    final containsStatements = <String>[];
    for (final m in contains.allMatches(flat)) {
      final found = XAllergenWords.find(m.group(1) ?? '');
      if (found.isEmpty) continue;
      containsStatements.add(m.group(0)!.trim());
      for (final a in found) {
        if (!containsFound.contains(a)) containsFound.add(a);
      }
    }
    final allergenInfo = RegExp(r'allergen\s*(information|advice|declaration)?\s*[:\-]\s*([^.]{1,200})', caseSensitive: false)
        .firstMatch(flat);
    if (allergenInfo != null && !RegExp(r'may\s+contain', caseSensitive: false).hasMatch(allergenInfo.group(2)!)) {
      for (final a in XAllergenWords.find(allergenInfo.group(2)!)) {
        if (!containsFound.contains(a)) containsFound.add(a);
      }
      if (containsStatements.isEmpty && containsFound.isNotEmpty) containsStatements.add(allergenInfo.group(0)!.trim());
    }

    result.allergens = containsFound;
    result.mayContain = mayContainFound.where((a) => !containsFound.contains(a)).toList();
    if (containsStatements.isNotEmpty) {
      result.containsStatement = containsStatements.join(' ');
      result.originals['allergens'] = result.containsStatement!;
    }
    if (statements.isNotEmpty) {
      result.mayContainStatement = statements.join(' ');
      result.originals['may_contain'] = result.mayContainStatement!;
    }
  }

  static void _readQuantities(String flat, LabelReadResult result) {
    final net = RegExp(
      r'\bnet\s*(?:wt|weight|qty|quantity|content|contents|mass|vol(?:ume)?)\.?\s*[:\-]?\s*(\d+(?:[.,]\d+)?)\s*(kg|g|gm|gms|grams?|ml|l|ltr|litres?)\b',
      caseSensitive: false,
    ).firstMatch(flat);
    if (net != null) {
      final unit = _unit(net.group(2)!);
      result.netQuantity = '${net.group(1)!.replaceAll(',', '.')} $unit';
      result.originals['net_quantity'] = net.group(0)!;
    }

    final serving = [
      RegExp(r'serv(?:ing|e)\s*size\s*[:\-]?\s*(?:\d+\s*[a-z]+\s*)?\(?\s*(\d+(?:[.,]\d+)?)\s*(g|gm|gms|ml)\b', caseSensitive: false),
      RegExp(r'\b1\s*serv(?:ing|e)\s*[=:\-]\s*(?:\d+\s*[a-z]+\s*)?\(?\s*(\d+(?:[.,]\d+)?)\s*(g|gm|gms|ml)\b', caseSensitive: false),
      RegExp(r'per\s*serv(?:ing|e)\s*\(?\s*(\d+(?:[.,]\d+)?)\s*(g|gm|gms|ml)\b', caseSensitive: false),
    ].map((r) => r.firstMatch(flat)).whereType<RegExpMatch>().firstOrNull;
    if (serving != null) {
      final amount = double.tryParse(serving.group(1)!.replaceAll(',', '.'));
      if (amount != null && amount > 0 && amount < 2000) {
        result.servingSize = amount;
        result.servingUnit = _unit(serving.group(2)!) == 'ml' ? 'ml' : 'g';
        result.originals['serving_size'] = serving.group(0)!;
      }
    }
  }

  static String _unit(String raw) {
    final u = raw.toLowerCase();
    if (u == 'kg') return 'kg';
    if (u == 'ml') return 'ml';
    if (u == 'l' || u.startsWith('lt') || u.startsWith('lit')) return 'l';
    return 'g';
  }

  static void _readBrand(String flat, LabelReadResult result) {
    for (final (name, pattern) in _brands) {
      final m = pattern.firstMatch(flat);
      if (m != null) {
        result.brand = name;
        result.originals['brand'] = m.group(0)!;
        return;
      }
    }
  }

  static final _notAName = RegExp(
    r'(ingredient|nutrition|allergen|contains|net\s*(wt|qty|weight)|mrp|fssai|best before|use by|mfd|batch|'
    r'manufactured|marketed|customer|energy|protein|carbohydrate|per\s+100|serv(e|ing)|www\.|@|veg)',
    caseSensitive: false,
  );

  /// The biggest text on the front photo is usually the product name. It is only a suggestion.
  static void _readName(OcrPage front, LabelReadResult result) {
    OcrLine? best;
    for (final line in front.lines) {
      final letters = RegExp(r'[A-Za-z]').allMatches(line.text).length;
      if (letters < 3 || _notAName.hasMatch(line.text)) continue;
      if (best == null || line.height > best.height) best = line;
    }
    if (best != null) {
      result.name = best.text.trim();
      result.originals['name'] = best.text.trim();
    }
  }

  // ---------------------------------------------------------------------------
  // Nutrition table
  // ---------------------------------------------------------------------------
  static final _nutrientRows = <(String, RegExp)>[
    ('calories', RegExp(r'^(energy|calories|calorific value|energy value)\b')),
    ('protein_g', RegExp(r'^proteins?\b')),
    ('carbs_g', RegExp(r'^(total\s+)?carbohydrates?\b')),
    ('sugar_g', RegExp(r'^(total\s+)?sugars?\b')),
    ('saturated_fat_g', RegExp(r'^saturated(\s+fat|\s+fatty\s+acids)?\b')),
    ('fat_g', RegExp(r'^(total\s+)?fats?\b(?!ty)')),
    ('fiber_g', RegExp(r'^(total\s+)?(dietary\s+)?fib(re|er)\b')),
    ('sodium_mg', RegExp(r'^sodium\b')),
    ('salt', RegExp(r'^salt\b')),
  ];

  /// Highest believable value per 100 g/ml; anything above is a misread and is dropped.
  static const _maxPer100 = {
    'calories': 900.0, 'protein_g': 100.0, 'carbs_g': 100.0, 'sugar_g': 100.0, 'saturated_fat_g': 100.0,
    'fat_g': 100.0, 'fiber_g': 100.0, 'sodium_mg': 40000.0, 'salt': 100.0,
  };

  static final _numberWord = RegExp(r'^[<~≤]?\(?(\d+(?:[.,]\d+)?)\)?(kcal|kj|g|gm|mg|ml)?\*?$', caseSensitive: false);

  static void _readNutritionTable(OcrPage page, LabelReadResult result) {
    final rows = _rows(page);
    if (rows.isEmpty) return;

    // Header: where are the "per 100 g" and "per serve" columns?
    double? per100X;
    double? perServeX;
    for (final row in rows) {
      for (var i = 0; i < row.length; i++) {
        final w = row[i].text.toLowerCase();
        final next = i + 1 < row.length ? row[i + 1].text.toLowerCase() : '';
        final hundred = RegExp(r'^\(?100(g|ml)?\)?$').firstMatch(w);
        if (hundred != null) {
          final unit = hundred.group(1) ?? (next.startsWith('ml') ? 'ml' : next.startsWith('g') ? 'g' : null);
          if (unit != null && per100X == null) {
            per100X = row[i].centerX;
            if (result.basis == null || !result.basisFromHeader) {
              result.basis = unit == 'ml' ? 'per_100ml' : 'per_100g';
              result.basisFromHeader = true;
            }
          }
        }
        if ((w.startsWith('serv') || w == 'serve') && perServeX == null && i > 0 &&
            RegExp(r'^per$', caseSensitive: false).hasMatch(row[i - 1].text)) {
          perServeX = row[i].centerX;
        }
      }
    }
    final usePerServe = per100X == null && perServeX != null;
    if (usePerServe && !result.basisFromHeader) {
      result.basis = 'per_serving';
      result.basisFromHeader = true;
    }

    for (final row in rows) {
      final labelWords = <OcrWord>[];
      final numbers = <(OcrWord, double, String?)>[];
      for (final w in row) {
        final m = _numberWord.firstMatch(w.text.replaceAll(',', '.').replaceAll('O', '0'));
        final isPercent = w.text.contains('%');
        if (m != null && !isPercent && labelWords.isNotEmpty) {
          numbers.add((w, double.parse(m.group(1)!), m.group(2)?.toLowerCase()));
        } else if (numbers.isEmpty) {
          labelWords.add(w);
        }
      }
      if (labelWords.isEmpty || numbers.isEmpty) continue;
      var label = labelWords.map((w) => w.text).join(' ').toLowerCase();
      label = label.replaceFirst(RegExp(r'^[\-•*·\s]*(of\s+which\s*[:\-]?\s*)?'), '').trim();
      if (label.startsWith('added') || label.startsWith('trans') || label.contains('mono') || label.contains('poly')) continue;

      final key = _nutrientRows.where((r) => r.$2.hasMatch(label)).map((r) => r.$1).firstOrNull;
      if (key == null) continue;
      if (key != 'calories' && result.nutrition.containsKey(key)) continue;
      if (key == 'salt' && result.nutrition.containsKey('sodium_mg')) continue;

      // Pick the number in the per-100 column (or per-serve column, or the first number).
      final columnX = per100X ?? perServeX;
      var pick = numbers.first;
      if (columnX != null) {
        pick = numbers.reduce((a, b) => (a.$1.centerX - columnX).abs() <= (b.$1.centerX - columnX).abs() ? a : b);
      }
      var value = pick.$2;
      final rowText = row.map((w) => w.text).join(' ');
      final rowLower = rowText.toLowerCase();

      if (key == 'calories') {
        if (result.nutrition.containsKey('calories') && !result.converted.contains('calories')) continue;
        // "Energy 1900 kJ / 454 kcal": take the kcal number when both are printed.
        final kcalWord = numbers.where((n) => n.$3 == 'kcal').firstOrNull;
        final kcalLabel = rowLower.contains('kcal');
        final kjOnly = (rowLower.contains('kj') && !kcalLabel) || pick.$3 == 'kj';
        if (kcalWord != null) {
          value = kcalWord.$2;
        } else if (kjOnly) {
          value = value / 4.184;
          result.converted.add('calories');
        } else {
          result.converted.remove('calories');
        }
        if (!_plausible(key, value, result.basis)) continue;
        result.nutrition['calories'] = _round(value);
        result.originals['calories'] = rowText;
        continue;
      }

      if (key == 'sodium_mg') {
        final inGrams = pick.$3 == 'g' || RegExp(r'\(\s*g\s*\)|\bg\b').hasMatch(label);
        if (inGrams && pick.$3 != 'mg') {
          value = value * 1000;
          result.converted.add('sodium_mg');
        }
      }
      if (key == 'salt') {
        if (!_plausible('salt', value, result.basis)) continue;
        result.nutrition['sodium_mg'] = _round(value * 400);
        result.converted.add('sodium_mg');
        result.originals['sodium_mg'] = rowText;
        continue;
      }
      if (!_plausible(key, value, result.basis)) continue;
      result.nutrition[key] = _round(value);
      result.originals[key] = rowText;
    }
  }

  static bool _plausible(String key, double value, String? basis) {
    if (value < 0) return false;
    final max = _maxPer100[key] ?? 1000;
    // A serving can be bigger than 100 g, so allow more when the column is per serving.
    return value <= (basis == 'per_serving' ? max * 10 : max);
  }

  static double _round(double v) => double.parse(v.toStringAsFixed(2));

  /// Words grouped into table rows by their vertical position, each row sorted left to right.
  static List<List<OcrWord>> _rows(OcrPage page) {
    final words = [for (final line in page.lines) ...line.words]..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<OcrWord>>[];
    for (final w in words) {
      final row = rows.isEmpty ? null : rows.last;
      if (row != null) {
        final cy = row.map((x) => x.centerY).reduce((a, b) => a + b) / row.length;
        final h = row.map((x) => x.height).reduce((a, b) => a > b ? a : b);
        if ((w.centerY - cy).abs() <= 0.5 * (h > w.height ? h : w.height)) {
          row.add(w);
          continue;
        }
      }
      rows.add([w]);
    }
    for (final row in rows) {
      row.sort((a, b) => a.left.compareTo(b.left));
    }
    return rows;
  }
}
