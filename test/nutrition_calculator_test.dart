import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/nutrition/models/food_item_model.dart';
import 'package:nutrisafe/features/nutrition/models/nutrition_values.dart';
import 'package:nutrisafe/features/personalization/models/user_model.dart';
import 'package:nutrisafe/utils/constants/enums.dart';
import 'package:nutrisafe/utils/helpers/helper_function.dart';
import 'package:nutrisafe/utils/helpers/nutrition_calculator.dart';

void main() {
  final rice = FoodItemModel(
    name: 'Rice',
    basis: NutritionBasis.per100g,
    unitWeights: const {'katori': 150},
    nutrition: const NutritionValues(calories: 130, proteinG: 2.7, fiberG: null),
  );

  group('XNutritionCalculator.forQuantity', () {
    test('scales per-100g values by grams', () {
      final result = XNutritionCalculator.forQuantity(rice, 150, 'g')!;
      expect(result.calories, closeTo(195, 0.001));
      expect(result.proteinG, closeTo(4.05, 0.001));
    });

    test('uses household unit weights', () {
      final result = XNutritionCalculator.forQuantity(rice, 2, 'katori')!;
      expect(result.calories, closeTo(390, 0.001));
    });

    test('unknown nutrients stay unknown instead of becoming zero', () {
      final result = XNutritionCalculator.forQuantity(rice, 150, 'g')!;
      expect(result.fiberG, isNull);
    });

    test('returns null when the unit cannot be converted', () {
      expect(XNutritionCalculator.forQuantity(rice, 1, 'piece'), isNull);
    });

    test('per-serving food converts grams through the serving size', () {
      final biscuit = FoodItemModel(
        name: 'Biscuit',
        basis: NutritionBasis.perServing,
        servingSize: 25,
        nutrition: const NutritionValues(calories: 120),
      );
      expect(XNutritionCalculator.forQuantity(biscuit, 2, 'serving')!.calories, 240);
      expect(XNutritionCalculator.forQuantity(biscuit, 50, 'g')!.calories, 240);
    });
  });

  group('NutritionValues', () {
    test('sum keeps a nutrient unknown only when both sides are unknown', () {
      const a = NutritionValues(calories: 100, proteinG: null, fiberG: null);
      const b = NutritionValues(calories: 50, proteinG: 5, fiberG: null);
      final sum = a + b;
      expect(sum.calories, 150);
      expect(sum.proteinG, 5);
      expect(sum.fiberG, isNull);
    });
  });

  group('XNutritionCalculator.suggestGoals', () {
    test('falls back to general defaults when the profile is incomplete', () {
      final goals = XNutritionCalculator.suggestGoals(UserModel(id: 'x'));
      expect(goals.calories, 2000);
      expect(goals.isCustom, isFalse);
    });

    test('never suggests an extreme calorie target', () {
      final small = XNutritionCalculator.suggestGoals(
        UserModel(
          id: 'x',
          dateOfBirth: DateTime(DateTime.now().year - 80),
          gender: 'female',
          heightCm: 140,
          weightKg: 35,
          activityLevel: 'sedentary',
        ),
      );
      expect(small.calories, greaterThanOrEqualTo(1400));
    });
  });

  group('XHelperFunctions.formatNumber', () {
    test('shows a dash for unknown values', () {
      expect(XHelperFunctions.formatNumber(null), '–');
    });

    test('trims trailing zeros', () {
      expect(XHelperFunctions.formatNumber(12.0), '12');
      expect(XHelperFunctions.formatNumber(12.34), '12.3');
      expect(XHelperFunctions.formatNumber(100, decimals: 0), '100');
    });
  });
}
