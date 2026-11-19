import '../../features/nutrition/models/food_item_model.dart';
import '../../features/nutrition/models/nutrition_goal_model.dart';
import '../../features/nutrition/models/nutrition_values.dart';
import '../../features/personalization/models/user_model.dart';
import '../constants/enums.dart';

class XNutritionCalculator {
  XNutritionCalculator._();

  /// -- Nutrition for the quantity the user confirmed.
  /// Returns null when the quantity cannot be converted (e.g. "piece" with no known weight);
  /// the caller must then ask the user instead of guessing.
  static NutritionValues? forQuantity(FoodItemModel food, double quantity, String unit) {
    final factor = _factor(food, quantity, unit);
    if (factor == null) return null;
    return food.nutrition.scale(factor);
  }

  static double? _factor(FoodItemModel food, double quantity, String unit) {
    switch (food.basis) {
      case NutritionBasis.per100g:
      case NutritionBasis.per100ml:
        if (unit == 'g' || unit == 'ml') return quantity / 100;
        final unitWeight = food.unitWeights[unit];
        if (unitWeight != null) return quantity * unitWeight / 100;
        if (unit == 'serving' && food.servingSize != null) {
          return quantity * food.servingSize! / 100;
        }
        return null;
      case NutritionBasis.perServing:
        if (unit == 'serving') return quantity;
        if ((unit == 'g' || unit == 'ml') && food.servingSize != null && food.servingSize! > 0) {
          return quantity / food.servingSize!;
        }
        return null;
      case NutritionBasis.perPackage:
        if (unit == 'package') return quantity;
        return null;
    }
  }

  /// -- Starting-point daily goals. These are general estimates the user can change,
  /// not a medical prescription.
  static NutritionGoalModel suggestGoals(UserModel user) {
    double calories = 2000;
    final age = user.age;
    final weight = user.weightKg;
    final height = user.heightCm;

    if (age != null && age >= 18 && weight != null && height != null) {
      // Mifflin-St Jeor resting energy estimate
      double bmr = 10 * weight + 6.25 * height - 5 * age;
      if (user.gender == 'male') {
        bmr += 5;
      } else if (user.gender == 'female') {
        bmr -= 161;
      } else {
        bmr -= 78;
      }
      const activity = {'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725};
      calories = bmr * (activity[user.activityLevel] ?? 1.375);
      // Never suggest extreme targets
      calories = calories.clamp(1400, 3500).toDouble();
      calories = (calories / 50).round() * 50;
    }

    return NutritionGoalModel(
      calories: calories,
      proteinG: weight != null && age != null && age >= 18
          ? (weight * 0.8).roundToDouble()
          : (calories * 0.15 / 4).roundToDouble(),
      carbsG: (calories * 0.55 / 4).roundToDouble(),
      fatG: (calories * 0.27 / 9).roundToDouble(),
      fiberG: (calories / 1000 * 14).roundToDouble(),
      sugarG: null,
      sodiumMg: 2000,
      waterMl: 2000,
      isCustom: false,
    );
  }
}
