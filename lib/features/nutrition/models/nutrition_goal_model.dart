class NutritionGoalModel {
  NutritionGoalModel({
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.fiberG,
    this.sugarG,
    this.sodiumMg,
    this.waterMl,
    this.isCustom = false,
  });

  final double? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final double? fiberG;
  final double? sugarG;
  final double? sodiumMg;
  final double? waterMl;
  final bool isCustom;

  static double? _num(dynamic value) => value == null ? null : (value as num).toDouble();

  factory NutritionGoalModel.fromJson(Map<String, dynamic> json) {
    return NutritionGoalModel(
      calories: _num(json['calories']),
      proteinG: _num(json['protein_g']),
      carbsG: _num(json['carbs_g']),
      fatG: _num(json['fat_g']),
      fiberG: _num(json['fiber_g']),
      sugarG: _num(json['sugar_g']),
      sodiumMg: _num(json['sodium_mg']),
      waterMl: _num(json['water_ml']),
      isCustom: json['is_custom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'calories': calories,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
      'fiber_g': fiberG,
      'sugar_g': sugarG,
      'sodium_mg': sodiumMg,
      'water_ml': waterMl,
      'is_custom': isCustom,
    };
  }
}
