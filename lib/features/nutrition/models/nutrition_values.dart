/// -- A set of nutrient amounts. A null field means "unknown" and is never treated as zero
/// when shown to the user.
class NutritionValues {
  const NutritionValues({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.saturatedFatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
  });

  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? saturatedFatG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;

  static const empty = NutritionValues();

  bool get isEmpty =>
      calories == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      fiberG == null &&
      sugarG == null &&
      sodiumMg == null;

  /// Multiply every known value (unknown stays unknown).
  NutritionValues scale(double factor) {
    double? s(double? v) => v == null ? null : v * factor;
    return NutritionValues(
      calories: s(calories),
      proteinG: s(proteinG),
      carbsG: s(carbsG),
      fatG: s(fatG),
      saturatedFatG: s(saturatedFatG),
      fiberG: s(fiberG),
      sugarG: s(sugarG),
      sodiumMg: s(sodiumMg),
    );
  }

  /// Sum of the known values of both sides.
  NutritionValues operator +(NutritionValues other) {
    double? a(double? x, double? y) => (x == null && y == null) ? null : (x ?? 0) + (y ?? 0);
    return NutritionValues(
      calories: a(calories, other.calories),
      proteinG: a(proteinG, other.proteinG),
      carbsG: a(carbsG, other.carbsG),
      fatG: a(fatG, other.fatG),
      saturatedFatG: a(saturatedFatG, other.saturatedFatG),
      fiberG: a(fiberG, other.fiberG),
      sugarG: a(sugarG, other.sugarG),
      sodiumMg: a(sodiumMg, other.sodiumMg),
    );
  }

  static double? _num(dynamic value) => value == null ? null : (value as num).toDouble();

  factory NutritionValues.fromJson(Map<String, dynamic> json) {
    return NutritionValues(
      calories: _num(json['calories']),
      proteinG: _num(json['protein_g']),
      carbsG: _num(json['carbs_g']),
      fatG: _num(json['fat_g']),
      saturatedFatG: _num(json['saturated_fat_g']),
      fiberG: _num(json['fiber_g']),
      sugarG: _num(json['sugar_g']),
      sodiumMg: _num(json['sodium_mg']),
    );
  }

  Map<String, dynamic> toJson() {
    double? r(double? v) => v == null ? null : double.parse(v.toStringAsFixed(2));
    return {
      'calories': r(calories),
      'protein_g': r(proteinG),
      'carbs_g': r(carbsG),
      'fat_g': r(fatG),
      'saturated_fat_g': r(saturatedFatG),
      'fiber_g': r(fiberG),
      'sugar_g': r(sugarG),
      'sodium_mg': r(sodiumMg),
    };
  }
}
