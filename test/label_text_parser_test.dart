import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/nutrition/models/product_draft.dart';
import 'package:nutrisafe/utils/helpers/allergen_words.dart';
import 'package:nutrisafe/utils/helpers/label_text_parser.dart';

/// Builds a photo's OCR result: each row is a list of cells placed at the given column x positions.
/// Words inside a cell follow each other, like the OCR engine reports them.
OcrPage page(List<List<String>> rows, {List<double> columns = const [0, 260, 420], double lineHeight = 20}) {
  final lines = <OcrLine>[];
  for (var r = 0; r < rows.length; r++) {
    final top = r * (lineHeight + 10);
    for (var c = 0; c < rows[r].length; c++) {
      var x = columns[c < columns.length ? c : columns.length - 1];
      final words = <OcrWord>[];
      for (final word in rows[r][c].split(' ').where((w) => w.isNotEmpty)) {
        final width = word.length * 9.0;
        words.add(OcrWord(word, x, top, x + width, top + lineHeight));
        x += width + 6;
      }
      lines.add(OcrLine(rows[r][c], words));
    }
  }
  return OcrPage(lines);
}

/// Running text (no table), one line per string.
OcrPage textPage(List<String> lines, {double height = 20}) => page([for (final l in lines) [l]], lineHeight: height);

void main() {
  final parleIngredients = textPage([
    'INGREDIENTS: Refined Wheat Flour (Maida), Sugar, Refined Palm Oil, Invert Sugar Syrup,',
    'Raising Agents [503(ii), 500(ii)], Iodised Salt, Milk Solids, Emulsifiers [322, 471].',
    'CONTAINS ADDED FLAVOURS (ARTIFICIAL FLAVOURING SUBSTANCES - VANILLA)',
    'ALLERGEN INFORMATION: Contains Wheat and Milk. May contain traces of Soy, Nuts and Sesame.',
    'Net Qty: 250 g    MRP Rs 30 (Incl. of all taxes)',
    'Manufactured by: Parle Products Pvt. Ltd., Mumbai',
  ]);

  final parleTable = page([
    ['NUTRITIONAL INFORMATION', 'Per 100 g', 'Per Serve (25 g)'],
    ['Energy (kcal)', '454', '114'],
    ['Protein (g)', '6.9', '1.7'],
    ['Carbohydrate (g)', '77.4', '19.4'],
    ['Total Sugars (g)', '25.0', '6.3'],
    ['Added Sugars (g)', '24.9', '6.2'],
    ['Total Fat (g)', '13.0', '3.3'],
    ['Saturated Fat (g)', '6.2', '1.6'],
    ['Trans Fat (g)', '0.1', '0.0'],
    ['Sodium (mg)', '290', '73'],
  ]);

  group('Ingredients and allergen statements', () {
    final r = XLabelTextParser.parse([parleIngredients]);

    test('ingredient list is read up to the next heading', () {
      expect(r.ingredientsText, startsWith('Refined Wheat Flour (Maida), Sugar'));
      expect(r.ingredientsText, contains('Emulsifiers [322, 471]'));
      expect(r.ingredientsText!.toLowerCase(), isNot(contains('allergen')));
    });

    test('"Contains" allergens are read; "contains added flavours" is ignored', () {
      expect(r.allergens, ['Wheat / Gluten', 'Milk']);
      expect(r.containsStatement, contains('Wheat and Milk'));
    });

    test('"May contain" allergens are kept apart', () {
      expect(r.mayContain, ['Tree nuts', 'Soy', 'Sesame']);
    });

    test('net quantity and brand', () {
      expect(r.netQuantity, '250 g');
      expect(r.brand, 'Parle');
    });
  });

  group('Nutrition table', () {
    final r = XLabelTextParser.parse([parleTable]);

    test('values come from the "per 100 g" column, not "per serve"', () {
      expect(r.basis, 'per_100g');
      expect(r.basisFromHeader, isTrue);
      expect(r.nutrition['calories'], 454);
      expect(r.nutrition['protein_g'], 6.9);
      expect(r.nutrition['carbs_g'], 77.4);
      expect(r.nutrition['sugar_g'], 25.0);
      expect(r.nutrition['fat_g'], 13.0);
      expect(r.nutrition['saturated_fat_g'], 6.2);
      expect(r.nutrition['sodium_mg'], 290);
    });

    test('added sugars and trans fat do not replace total sugars and total fat', () {
      expect(r.nutrition['sugar_g'], isNot(24.9));
      expect(r.nutrition['fat_g'], isNot(0.1));
    });

    test('nothing that is not printed is filled in', () {
      expect(r.nutrition.containsKey('fiber_g'), isFalse);
    });

    test('serving size from the header', () {
      expect(r.servingSize, 25);
      expect(r.servingUnit, 'g');
    });

    test('per-serve column first, per-100 g second', () {
      final swapped = page([
        ['Nutrition Facts', 'Per Serve (30 g)', 'Per 100 g'],
        ['Energy (kcal)', '150', '500'],
        ['Protein (g)', '2.1', '7.0'],
      ]);
      final s = XLabelTextParser.parse([swapped]);
      expect(s.nutrition['calories'], 500);
      expect(s.nutrition['protein_g'], 7.0);
    });

    test('per 100 ml drinks', () {
      final drink = page([
        ['Nutritional Information', 'Per 100 ml'],
        ['Energy (kcal)', '72'],
        ['Total Sugars (g)', '11.5'],
      ]);
      final d = XLabelTextParser.parse([drink]);
      expect(d.basis, 'per_100ml');
      expect(d.nutrition['sugar_g'], 11.5);
    });

    test('kJ only is converted to kcal and marked', () {
      final kj = page([
        ['', 'Per 100 g'],
        ['Energy (kJ)', '1900'],
      ]);
      final k = XLabelTextParser.parse([kj]);
      expect(k.nutrition['calories'], closeTo(454.1, 0.1));
      expect(k.converted, contains('calories'));
    });

    test('kcal preferred when kJ and kcal are both printed', () {
      final both = page([
        ['Typical values', 'Per 100 g'],
        ['Energy', '1900kJ 454kcal'],
      ]);
      expect(XLabelTextParser.parse([both]).nutrition['calories'], 454);
    });

    test('sodium printed in grams becomes mg; salt becomes sodium and is marked', () {
      final grams = page([
        ['', 'Per 100 g'],
        ['Sodium (g)', '0.29'],
      ]);
      expect(XLabelTextParser.parse([grams]).nutrition['sodium_mg'], 290);
      final salt = page([
        ['', 'Per 100 g'],
        ['Salt (g)', '1.0'],
      ]);
      final s = XLabelTextParser.parse([salt]);
      expect(s.nutrition['sodium_mg'], 400);
      expect(s.converted, contains('sodium_mg'));
    });

    test('a misread value that cannot be per 100 g is dropped, not saved', () {
      final misread = page([
        ['', 'Per 100 g'],
        ['Energy (kcal)', '4540'],
        ['Protein (g)', '69'],
      ]);
      final m = XLabelTextParser.parse([misread]);
      expect(m.nutrition.containsKey('calories'), isFalse);
      expect(m.nutrition['protein_g'], 69);
    });

    test('RDA % column is ignored', () {
      final rda = page([
        ['Nutrition', 'Per 100 g', '%RDA*'],
        ['Protein (g)', '6.9', '12%'],
      ]);
      expect(XLabelTextParser.parse([rda]).nutrition['protein_g'], 6.9);
    });
  });

  group('Several photos', () {
    final front = OcrPage([
      OcrLine('Parle', [const OcrWord('Parle', 0, 0, 80, 30)]),
      OcrLine('Parle-G', [const OcrWord('Parle-G', 0, 40, 300, 120)]),
      OcrLine('Original Gluco Biscuits', [const OcrWord('Original', 0, 130, 100, 150)]),
      OcrLine('Net Wt. 250 g', [const OcrWord('Net', 0, 160, 30, 180)]),
    ]);
    final r = XLabelTextParser.parse([front, parleIngredients, parleTable]);

    test('name suggestion is the largest text on the front photo', () {
      expect(r.name, 'Parle-G');
    });

    test('details from every photo are combined', () {
      expect(r.ingredientsText, isNotNull);
      expect(r.allergens, contains('Milk'));
      expect(r.nutrition['calories'], 454);
    });

    test('fields are marked as read from the label, name with low confidence', () {
      final fields = ProductDraft.fieldsFromLabel(r);
      expect(fields['calories']!.source, ProductDraft.labelSource);
      expect(fields['calories']!.status, 'from_label');
      expect(fields['name']!.confidence, 'low');
      expect(fields['basis']!.value, 'per_100g');
      expect(fields.containsKey('fiber_g'), isFalse);
    });
  });

  test('empty photo gives an empty result', () {
    expect(XLabelTextParser.parse([const OcrPage([])]).isEmpty, isTrue);
  });

  group('Allergen words', () {
    test('Hindi / Hinglish label words', () {
      expect(XAllergenWords.find('Atta, ghee, kaju, til, sarson ka tel'),
          ['Wheat / Gluten', 'Milk', 'Tree nuts', 'Sesame', 'Mustard']);
    });

    test('cocoa butter and peanut butter are not milk', () {
      expect(XAllergenWords.find('cocoa butter'), isEmpty);
      expect(XAllergenWords.find('peanut butter'), ['Peanut']);
    });

    test('profile allergen matched through label words', () {
      expect(XAllergenWords.mentions('Refined wheat flour (maida), ghee', 'Milk'), isTrue);
      expect(XAllergenWords.mentions('Refined wheat flour (maida)', 'Wheat / Gluten'), isTrue);
      expect(XAllergenWords.mentions('groundnut oil', 'Peanuts'), isTrue);
      expect(XAllergenWords.mentions('rice, salt', 'Milk'), isFalse);
    });
  });

  group('Product draft', () {
    test('label values only fill empty fields; database values are kept', () {
      final draft = ProductDraft(
        barcode: '8901719101038',
        fields: {
          'name': ProductField(value: 'Parle-G', source: 'open_food_facts', sourceLabel: 'Open Food Facts', status: 'found', confidence: 'medium'),
          'basis': ProductField(value: 'per_100g', source: 'open_food_facts', sourceLabel: 'Open Food Facts', status: 'found', confidence: 'medium'),
          'calories': ProductField(value: 450, source: 'open_food_facts', sourceLabel: 'Open Food Facts', status: 'found', confidence: 'medium'),
        },
      );
      final merged = draft.withMissingFrom(ProductDraft.fieldsFromLabel(XLabelTextParser.parse([parleTable])));
      expect(merged.number('calories'), 450); // kept
      expect(merged.number('protein_g'), 6.9); // filled from the label
      expect(merged.fields['protein_g']!.source, ProductDraft.labelSource);
    });

    test('label nutrition on another basis is not mixed in', () {
      final draft = ProductDraft(fields: {
        'basis': ProductField(value: 'per_100ml', source: 'usda_fdc', sourceLabel: 'USDA', status: 'found', confidence: 'high'),
        'calories': ProductField(value: 70, source: 'usda_fdc', sourceLabel: 'USDA', status: 'found', confidence: 'high'),
      });
      final merged = draft.withMissingFrom(ProductDraft.fieldsFromLabel(XLabelTextParser.parse([parleTable])));
      expect(merged.fields.containsKey('protein_g'), isFalse);
    });

    test('lookup JSON with a conflict', () {
      final d = ProductDraft.fromLookup({
        'status': 'found',
        'barcode': '8901719101038',
        'indian_barcode': true,
        'fields': {
          'calories': {
            'value': 456, 'source': 'usda_fdc', 'source_label': 'USDA FoodData Central', 'original': '456',
            'status': 'conflict', 'confidence': 'low',
            'alternatives': [{'source': 'open_food_facts', 'source_label': 'Open Food Facts', 'value': 540}],
          },
        },
        'providers': [
          {'source': 'open_food_facts', 'label': 'Open Food Facts', 'status': 'found'},
          {'source': 'nutritionix', 'label': 'Nutritionix', 'status': 'not_configured'},
          {'source': 'fatsecret', 'label': 'FatSecret', 'status': 'timeout'},
        ],
      });
      expect(d.conflicts, ['calories']);
      expect(d.fields['calories']!.alternatives.single.value, 540);
      expect(d.unavailable.map((p) => p.source), ['fatsecret']);
      expect(d.indianBarcode, isTrue);
      final food = d.toFoodItem();
      expect(food.nutrition.calories, 456);
      expect(food.nutrition.proteinG, isNull); // unknown stays unknown
    });
  });
}
