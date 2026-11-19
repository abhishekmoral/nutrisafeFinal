import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/food/food_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/helpers/allergen_words.dart';
import '../../../utils/helpers/helper_function.dart';
import '../../../utils/helpers/label_text_parser.dart';
import '../../../utils/localization/translations.dart';
import '../../../utils/popups/loaders.dart';
import '../models/food_item_model.dart';
import '../models/product_draft.dart';

/// -- Lets the person check and correct a product before it is saved.
/// Every value keeps its source; values the person changed are saved as "user_edited".
class ProductReviewController extends GetxController {
  ProductReviewController(ProductDraft draft) : draft = draft.obs;

  static const textKeys = ['name', 'brand', 'net_quantity', 'ingredients_text'];
  static const numberKeys = ['serving_size', ...ProductDraft.nutrientKeys];

  /// Highest believable value per 100 g/ml (a typo such as 4540 kcal is caught).
  static const maxPer100 = {
    'calories': 900.0, 'protein_g': 100.0, 'carbs_g': 100.0, 'fat_g': 100.0, 'saturated_fat_g': 100.0,
    'fiber_g': 100.0, 'sugar_g': 100.0, 'sodium_mg': 40000.0,
  };

  final Rx<ProductDraft> draft;
  final formKey = GlobalKey<FormState>();
  final inputs = <String, TextEditingController>{};
  final basis = 'per_100g'.obs;
  final servingUnit = 'g'.obs;
  final allergens = <String>[].obs;
  final mayContain = <String>[].obs;
  final resolved = <String>{}.obs; // conflicting fields the person has looked at
  final saving = false.obs;

  /// Values as they were found, to tell "confirmed" from "edited".
  final _initial = <String, String>{};

  @override
  void onInit() {
    super.onInit();
    for (final key in [...textKeys, ...numberKeys]) {
      inputs[key] = TextEditingController();
    }
    _fill(onlyEmpty: false);
  }

  ProductField? field(String key) => draft.value.fields[key];

  List<String> get openConflicts => draft.value.conflicts.where((k) => !resolved.contains(k)).toList();

  /// Puts the draft's values into the inputs (all of them, or only the empty ones).
  void _fill({required bool onlyEmpty}) {
    final d = draft.value;
    final nutritionWasEmpty = ProductDraft.nutrientKeys.every((k) => inputs[k]!.text.trim().isEmpty);
    final servingWasEmpty = inputs['serving_size']!.text.trim().isEmpty;
    for (final key in textKeys) {
      if (onlyEmpty && inputs[key]!.text.trim().isNotEmpty) continue;
      final value = d.text(key) ?? '';
      inputs[key]!.text = value;
      _initial[key] = value;
    }
    for (final key in numberKeys) {
      if (onlyEmpty && inputs[key]!.text.trim().isNotEmpty) continue;
      final n = d.number(key);
      final value = n == null ? '' : XHelperFunctions.formatNumber(n, decimals: 2);
      inputs[key]!.text = value;
      _initial[key] = value;
    }
    if (!onlyEmpty || nutritionWasEmpty) {
      basis.value = const ['per_100g', 'per_100ml', 'per_serving'].contains(d.text('basis')) ? d.text('basis')! : 'per_100g';
      _initial['basis'] = basis.value;
    }
    if (!onlyEmpty || servingWasEmpty) {
      servingUnit.value = d.text('serving_unit') == 'ml' ? 'ml' : 'g';
      _initial['serving_unit'] = servingUnit.value;
    }
    if (!onlyEmpty || allergens.isEmpty) {
      allergens.assignAll(d.list('allergens'));
      _initial['allergens'] = allergens.join('|');
    }
    if (!onlyEmpty || mayContain.isEmpty) {
      mayContain.assignAll(d.list('may_contain'));
      _initial['may_contain'] = mayContain.join('|');
    }
  }

  /// Allergen chips to offer: the app's list plus anything the sources named.
  List<String> get allergenOptions {
    final options = [...XAllergenWords.names];
    for (final a in [...allergens, ...mayContain, ...draft.value.list('allergens'), ...draft.value.list('may_contain')]) {
      if (!options.contains(a)) options.add(a);
    }
    return options;
  }

  void toggle(RxList<String> list, String allergen, String key) {
    list.contains(allergen) ? list.remove(allergen) : list.add(allergen);
    resolved.add(key);
  }

  /// The person picked one of the values the databases disagree on.
  void chooseAlternative(String key, Object? value) {
    if (value is List) {
      (key == 'allergens' ? allergens : mayContain).assignAll(value.map((e) => e.toString()));
    } else if (numberKeys.contains(key) && value is num) {
      inputs[key]!.text = XHelperFunctions.formatNumber(value.toDouble(), decimals: 2);
    } else if (inputs.containsKey(key)) {
      inputs[key]!.text = value?.toString() ?? '';
    }
    resolved.add(key);
  }

  void keepValue(String key) => resolved.add(key);

  void markEdited(String key) {
    if (field(key)?.isConflict == true) resolved.add(key);
  }

  /// Adds what the label photos show to the fields that are still empty.
  void applyLabel(LabelReadResult label) {
    final before = draft.value.fields.keys.toSet();
    draft.value = draft.value.withMissingFrom(ProductDraft.fieldsFromLabel(label));
    _fill(onlyEmpty: true);
    final added = draft.value.fields.keys.toSet().difference(before).length;
    if (added == 0) {
      XLoaders.warningSnackBar(
        title: 'Nothing new on the photos'.tr,
        message: 'Fill in the empty fields from the pack yourself.'.tr,
      );
    } else {
      XLoaders.successSnackBar(
        title: 'Label read'.tr,
        message: '{count} values filled in. Check them against the pack.'.trf({'count': added}),
      );
    }
  }

  bool get hasEmptyFields =>
      [...textKeys, ...numberKeys].any((k) => inputs[k]!.text.trim().isEmpty) || allergens.isEmpty;

  String? validateNumber(String key, String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null; // unknown is allowed; it stays unknown
    final value = double.tryParse(text.replaceAll(',', '.'));
    if (value == null || value < 0) return 'Enter a number'.tr;
    if (key == 'serving_size' && value == 0) return 'Enter a number'.tr;
    final max = maxPer100[key];
    if (max != null && basis.value != 'per_serving' && value > max) {
      return 'Too high for {basis}'.trf({'basis': basis.value == 'per_100ml' ? 'per 100 ml'.tr : 'per 100 g'.tr});
    }
    return null;
  }

  double? _number(String key) {
    final text = inputs[key]!.text.trim().replaceAll(',', '.');
    return text.isEmpty ? null : double.tryParse(text);
  }

  String _current(String key) {
    switch (key) {
      case 'basis':
        return basis.value;
      case 'serving_unit':
        return servingUnit.value;
      case 'allergens':
        return allergens.join('|');
      case 'may_contain':
        return mayContain.join('|');
      default:
        return inputs[key]!.text.trim();
    }
  }

  /// Source, original value and verification status of every field that has a value.
  Map<String, dynamic> _fieldSources() {
    final out = <String, dynamic>{};
    for (final key in [...textKeys, ...numberKeys, 'basis', 'serving_unit', 'allergens', 'may_contain']) {
      final value = _current(key);
      if (value.isEmpty) continue;
      final f = field(key);
      final edited = value != (_initial[key] ?? '');
      out[key] = {
        'source': f == null ? 'user' : f.source,
        'source_label': f == null ? 'Entered by you' : f.sourceLabel,
        'original': f?.original,
        'confidence': f?.confidence,
        'status': f == null ? 'user_entered' : (edited ? 'user_edited' : 'user_confirmed'),
        if (f?.isConflict == true) 'had_conflict': true,
      };
    }
    return out;
  }

  String get _productSource {
    final sources = draft.value.fields.values.map((f) => f.source).toSet();
    if (sources.isEmpty) return 'user';
    if (sources.length > 1) return 'multiple';
    final only = sources.first;
    const allowed = ['open_food_facts', 'usda_fdc', 'nutritionix', 'fatsecret', 'label_ocr'];
    return allowed.contains(only) ? only : 'user';
  }

  /// Saves the product and returns it as a food for the quantity step (null if not saved).
  Future<FoodItemModel?> save() async {
    if (saving.value || !formKey.currentState!.validate()) return null;
    saving.value = true;
    try {
      final d = draft.value;
      final payload = {
        'barcode': d.barcode,
        'name': inputs['name']!.text.trim(),
        'brand': inputs['brand']!.text.trim(),
        'net_quantity': inputs['net_quantity']!.text.trim(),
        'serving_size': _number('serving_size'),
        'serving_unit': _number('serving_size') == null ? null : servingUnit.value,
        'image_url': d.text('image_url'),
        'allergens': allergens.toList(),
        'may_contain': mayContain.toList(),
        'ingredients_text': inputs['ingredients_text']!.text.trim(),
        'source': _productSource,
        'field_sources': _fieldSources(),
        'nutrition': {
          'basis': basis.value,
          if (basis.value == 'per_serving' && _number('serving_size') != null) ...{
            'basis_quantity': _number('serving_size'),
            'basis_unit': servingUnit.value,
          },
          for (final key in ProductDraft.nutrientKeys) key: _number(key),
          'source': d.sourceSummary,
        },
      };
      await Get.put(FoodRepository()).saveConfirmedProduct(payload);

      // The saved values, as a food for the quantity step.
      final saved = ProductDraft(
        barcode: d.barcode,
        status: 'saved',
        fields: {
          for (final key in [...textKeys, ...numberKeys])
            if (_current(key).isNotEmpty)
              key: ProductField(
                value: numberKeys.contains(key) ? _number(key) : _current(key),
                source: field(key)?.source ?? 'user',
                sourceLabel: field(key)?.sourceLabel ?? '',
                status: 'user_confirmed',
                confidence: 'high',
              ),
          'basis': ProductField(value: basis.value, source: 'user', sourceLabel: '', status: 'user_confirmed', confidence: 'high'),
          'serving_unit': ProductField(value: servingUnit.value, source: 'user', sourceLabel: '', status: 'user_confirmed', confidence: 'high'),
          'allergens': ProductField(value: allergens.toList(), source: 'user', sourceLabel: '', status: 'user_confirmed', confidence: 'high'),
          'may_contain': ProductField(value: mayContain.toList(), source: 'user', sourceLabel: '', status: 'user_confirmed', confidence: 'high'),
          if (d.text('image_url') != null) 'image_url': d.fields['image_url']!,
        },
      );
      return saved.toFoodItem();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save product'.tr, message: XExceptionHandler.message(e));
      return null;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    for (final c in inputs.values) {
      c.dispose();
    }
    super.onClose();
  }
}
