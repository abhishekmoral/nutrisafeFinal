import 'package:get/get.dart';

import '../../../utils/constants/enums.dart';
import '../../../utils/helpers/label_text_parser.dart';
import 'food_item_model.dart';
import 'nutrition_values.dart';

/// Where a value came from and how far it can be trusted.
class ProductField {
  ProductField({
    required this.value,
    required this.source,
    required this.sourceLabel,
    this.original,
    required this.status,
    required this.confidence,
    this.alternatives = const [],
  });

  final Object? value;
  final String source; // open_food_facts | usda_fdc | nutritionix | fatsecret | label_ocr | user | manufacturer
  final String sourceLabel;
  final String? original; // the value as the source gave it
  /// found | converted | conflict | from_label | user_confirmed | user_edited | verified
  final String status;
  final String confidence; // high | medium | low
  final List<FieldAlternative> alternatives;

  bool get isConflict => status == 'conflict';

  factory ProductField.fromJson(Map<String, dynamic> json) => ProductField(
        value: json['value'],
        source: json['source'] as String? ?? 'user',
        sourceLabel: json['source_label'] as String? ?? '',
        original: json['original'] as String?,
        status: json['status'] as String? ?? 'found',
        confidence: json['confidence'] as String? ?? 'medium',
        alternatives: ((json['alternatives'] as List?) ?? const [])
            .map((a) => FieldAlternative.fromJson(Map<String, dynamic>.from(a as Map)))
            .toList(),
      );
}

class FieldAlternative {
  const FieldAlternative({required this.source, required this.sourceLabel, required this.value});

  final String source;
  final String sourceLabel;
  final Object? value;

  factory FieldAlternative.fromJson(Map<String, dynamic> json) => FieldAlternative(
        source: json['source'] as String? ?? '',
        sourceLabel: json['source_label'] as String? ?? '',
        value: json['value'],
      );
}

/// What one product database answered.
class ProviderReport {
  const ProviderReport({required this.source, required this.label, required this.status});

  final String source;
  final String label;
  final String status; // found | cached | not_found | error | timeout | rate_limited | not_configured | not_allowed

  bool get answered => status == 'found' || status == 'cached' || status == 'not_found';

  factory ProviderReport.fromJson(Map<String, dynamic> json) => ProviderReport(
        source: json['source'] as String? ?? '',
        label: json['label'] as String? ?? '',
        status: json['status'] as String? ?? 'error',
      );
}

/// -- A packaged product before the person confirms it: every field with its source.
class ProductDraft {
  ProductDraft({
    this.barcode,
    this.productId,
    this.status = 'found',
    Map<String, ProductField>? fields,
    this.providers = const [],
    this.savedByYou = false,
    this.indianBarcode = false,
  }) : fields = fields ?? {};

  static const nutrientKeys = [
    'calories', 'protein_g', 'carbs_g', 'fat_g', 'saturated_fat_g', 'fiber_g', 'sugar_g', 'sodium_mg',
  ];

  static const labelSource = 'label_ocr';
  static String get labelSourceLabel => 'Package label photo'.tr;

  final String? barcode;
  final String? productId;
  final String status; // saved | found | not_found
  final Map<String, ProductField> fields;
  final List<ProviderReport> providers;
  final bool savedByYou;
  final bool indianBarcode;

  bool get isSaved => status == 'saved';
  bool get isNotFound => status == 'not_found';
  List<String> get conflicts => [for (final e in fields.entries) if (e.value.isConflict) e.key];

  /// Databases that could not be asked (offline, outage, limit) - the result may be incomplete.
  List<ProviderReport> get unavailable =>
      providers.where((p) => !p.answered && p.status != 'not_configured').toList();

  /// Short line naming where the values came from, e.g. "Open Food Facts, USDA FoodData Central".
  String get sourceSummary {
    final labels = <String>[];
    for (final f in fields.values) {
      if (f.sourceLabel.isNotEmpty && !labels.contains(f.sourceLabel)) labels.add(f.sourceLabel);
    }
    return labels.join(', ');
  }

  String? text(String key) {
    final v = fields[key]?.value;
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  double? number(String key) {
    final v = fields[key]?.value;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  List<String> list(String key) {
    final v = fields[key]?.value;
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  factory ProductDraft.fromLookup(Map<String, dynamic> json) {
    final rawFields = Map<String, dynamic>.from((json['fields'] as Map?) ?? const {});
    return ProductDraft(
      barcode: json['barcode'] as String?,
      productId: json['product_id'] as String?,
      status: json['status'] as String? ?? 'not_found',
      savedByYou: json['saved_by_you'] == true,
      indianBarcode: json['indian_barcode'] == true,
      fields: {
        for (final e in rawFields.entries) e.key: ProductField.fromJson(Map<String, dynamic>.from(e.value as Map)),
      },
      providers: ((json['providers'] as List?) ?? const [])
          .map((p) => ProviderReport.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
    );
  }

  /// Fields read from label photos. Only text that was on the photos is used.
  static Map<String, ProductField> fieldsFromLabel(LabelReadResult label) {
    final out = <String, ProductField>{};
    void put(String key, Object? value, {String confidence = 'medium'}) {
      if (value == null || (value is String && value.trim().isEmpty) || (value is List && value.isEmpty)) return;
      out[key] = ProductField(
        value: value,
        source: labelSource,
        sourceLabel: labelSourceLabel,
        original: label.originals[key],
        status: label.converted.contains(key) ? 'converted' : 'from_label',
        confidence: label.converted.contains(key) ? 'medium' : confidence,
      );
    }

    put('name', label.name, confidence: 'low'); // largest text on the pack: a suggestion only
    put('brand', label.brand);
    put('net_quantity', label.netQuantity);
    put('serving_size', label.servingSize);
    put('serving_unit', label.servingUnit);
    put('ingredients_text', label.ingredientsText);
    put('allergens', label.allergens);
    put('may_contain', label.mayContain);
    if (label.nutrition.isNotEmpty) {
      put('basis', label.basis ?? 'per_100g', confidence: label.basisFromHeader ? 'medium' : 'low');
      for (final e in label.nutrition.entries) {
        put(e.key, e.value);
      }
    }
    return out;
  }

  /// Fills only the fields that are still empty (values found in databases are never replaced).
  ProductDraft withMissingFrom(Map<String, ProductField> extra) {
    final merged = Map<String, ProductField>.from(fields);
    final nutritionEmpty = !nutrientKeys.any(fields.containsKey);
    extra.forEach((key, field) {
      if (merged.containsKey(key)) return;
      // Nutrients from the label are only used together with the label's own basis.
      final isNutrition = nutrientKeys.contains(key) || key == 'basis';
      if (isNutrition && !nutritionEmpty) {
        final sameBasis = extra['basis']?.value == fields['basis']?.value;
        if (!sameBasis) return;
      }
      merged[key] = field;
    });
    return ProductDraft(
      barcode: barcode,
      productId: productId,
      status: status,
      fields: merged,
      providers: providers,
      savedByYou: savedByYou,
      indianBarcode: indianBarcode,
    );
  }

  NutritionValues get nutrition => NutritionValues(
        calories: number('calories'),
        proteinG: number('protein_g'),
        carbsG: number('carbs_g'),
        fatG: number('fat_g'),
        saturatedFatG: number('saturated_fat_g'),
        fiberG: number('fiber_g'),
        sugarG: number('sugar_g'),
        sodiumMg: number('sodium_mg'),
      );

  /// The confirmed product as a food the diary can use.
  FoodItemModel toFoodItem() {
    final basis = NutritionBasis.fromValue(text('basis'));
    final n = nutrition;
    final fromLabel = fields.values.any((f) => f.source == labelSource);
    return FoodItemModel(
      barcode: barcode,
      name: text('name') ?? 'Packaged product'.tr,
      brand: text('brand'),
      imageUrl: text('image_url'),
      basis: basis,
      servingSize: number('serving_size'),
      servingUnit: text('serving_unit') ?? (basis == NutritionBasis.per100ml ? 'ml' : 'g'),
      nutrition: n,
      quality: n.isEmpty ? NutritionQuality.unknown : NutritionQuality.estimated,
      entrySource: fromLabel ? 'label_ocr' : 'barcode',
      allergens: [...list('allergens'), ...list('may_contain')],
      ingredientsText: text('ingredients_text'),
      source: sourceSummary,
    );
  }
}
