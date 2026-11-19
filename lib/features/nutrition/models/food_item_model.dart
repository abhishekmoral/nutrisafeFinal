import 'package:get/get.dart';

import '../../../utils/constants/enums.dart';
import 'nutrition_values.dart';

/// -- A food the user can pick: from the curated catalog, Open Food Facts, or typed manually.
class FoodItemModel {
  FoodItemModel({
    this.foodId,
    this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.basis = NutritionBasis.per100g,
    this.servingSize,
    this.servingUnit,
    this.unitWeights = const {},
    this.nutrition = NutritionValues.empty,
    this.quality = NutritionQuality.unknown,
    this.entrySource = 'manual',
    this.allergens = const [],
    this.ingredientsText,
    this.source,
  });

  /// Household units in the order they are offered (the first one is the default).
  static const _unitOrder = ['piece', 'slice', 'katori', 'glass', 'tbsp', 'tsp', 'cup'];

  /// Text shown for a unit. Katori and glass are fixed volumes so the weight is defined.
  static String unitLabel(String unit) {
    switch (unit) {
      case 'katori':
        return 'katori (150 ml)'.tr;
      case 'glass':
        return 'glass (250 ml)'.tr;
      case 'cup':
        return 'cup (240 ml)'.tr;
      default:
        return unit;
    }
  }

  final String? foodId; // id in the `foods` table (catalog items only)
  final String? barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final NutritionBasis basis;
  final double? servingSize; // grams or ml in one serving, when known
  final String? servingUnit;
  final Map<String, double> unitWeights; // household unit -> grams
  final NutritionValues nutrition; // values for [basis]
  final NutritionQuality quality;
  final String entrySource; // manual | catalog | barcode
  final List<String> allergens;
  final String? ingredientsText;
  final String? source; // where the nutrition values come from, e.g. USDA FoodData Central

  /// Units the quantity can be entered in for this food.
  List<String> get availableUnits {
    final units = <String>[];
    switch (basis) {
      case NutritionBasis.per100g:
        units.add('g');
      case NutritionBasis.per100ml:
        units.add('ml');
      case NutritionBasis.perServing:
        units.add('serving');
        if (servingSize != null) units.add(servingUnit == 'ml' ? 'ml' : 'g');
      case NutritionBasis.perPackage:
        units.add('package');
    }
    if (basis == NutritionBasis.per100g || basis == NutritionBasis.per100ml) {
      units.addAll(unitWeights.keys);
      if (servingSize != null) units.add('serving');
    }
    return units;
  }

  /// Row of `foods` joined with `food_nutrition`.
  factory FoodItemModel.fromCatalog(Map<String, dynamic> json) {
    final nutritionRows = (json['food_nutrition'] as List?) ?? const [];
    final nutrition = nutritionRows.isEmpty
        ? null
        : Map<String, dynamic>.from(nutritionRows.first as Map);
    final rawWeights = <String, double>{};
    ((json['unit_weights'] as Map?) ?? const {}).forEach((key, value) {
      if (value is num) rawWeights[key.toString()] = value.toDouble();
    });
    // The database does not keep the order of the units, so sort them here.
    final keys = rawWeights.keys.toList()
      ..sort((a, b) {
        final ia = _unitOrder.indexOf(a), ib = _unitOrder.indexOf(b);
        return (ia < 0 ? 99 : ia).compareTo(ib < 0 ? 99 : ib);
      });
    final weights = {for (final key in keys) key: rawWeights[key]!};
    return FoodItemModel(
      foodId: json['id'] as String?,
      name: json['name'] as String,
      basis: NutritionBasis.fromValue(nutrition?['basis'] as String?),
      unitWeights: weights,
      nutrition: nutrition == null ? NutritionValues.empty : NutritionValues.fromJson(nutrition),
      quality: nutrition == null
          ? NutritionQuality.unknown
          : (json['is_verified'] == true ? NutritionQuality.verified : NutritionQuality.estimated),
      entrySource: 'catalog',
      source: json['source'] as String?,
    );
  }
}
