import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/nutrition/models/food_item_model.dart';
import 'package:nutrisafe/utils/constants/enums.dart';
import 'package:nutrisafe/utils/helpers/nutrition_calculator.dart';

void main() {
  // A row as the app receives it from the `foods` table (values of "Rice, white, cooked").
  Map<String, dynamic> riceRow() => {
    'id': 'food-1',
    'name': 'Rice, white, cooked',
    'is_verified': false,
    'source': 'USDA FoodData Central, FNDDS 2021-2023',
    // The database returns units in no particular order.
    'unit_weights': {'cup': 158.0, 'katori': 100},
    'food_nutrition': [
      {
        'basis': 'per_100g',
        'calories': 129,
        'protein_g': 2.67,
        'carbs_g': 28,
        'fat_g': 0.28,
        'saturated_fat_g': 0.08,
        'fiber_g': 0.4,
        'sugar_g': 0.05,
        'sodium_mg': 245,
      },
    ],
  };

  group('FoodItemModel.fromCatalog', () {
    test('reads nutrition, source and marks unverified data as estimated', () {
      final food = FoodItemModel.fromCatalog(riceRow());
      expect(food.name, 'Rice, white, cooked');
      expect(food.basis, NutritionBasis.per100g);
      expect(food.nutrition.calories, 129);
      expect(food.source, 'USDA FoodData Central, FNDDS 2021-2023');
      expect(food.quality, NutritionQuality.estimated);
      expect(food.entrySource, 'catalog');
    });

    test('offers household units in a fixed order, katori before cup', () {
      final food = FoodItemModel.fromCatalog(riceRow());
      expect(food.unitWeights.keys.toList(), ['katori', 'cup']);
      expect(food.availableUnits, ['g', 'katori', 'cup']);
    });

    test('piece comes first, spoons before cup', () {
      final row = riceRow()..['unit_weights'] = {'cup': 224.0, 'tsp': 4.7, 'tbsp': 14.0, 'piece': 40};
      expect(FoodItemModel.fromCatalog(row).unitWeights.keys.toList(), ['piece', 'tbsp', 'tsp', 'cup']);
    });

    test('a food without nutrition rows has unknown quality and no values', () {
      final row = riceRow()..['food_nutrition'] = [];
      final food = FoodItemModel.fromCatalog(row);
      expect(food.quality, NutritionQuality.unknown);
      expect(food.nutrition.isEmpty, isTrue);
    });
  });

  group('catalog food + calculator', () {
    test('2 katori of rice uses the katori weight', () {
      final food = FoodItemModel.fromCatalog(riceRow());
      final result = XNutritionCalculator.forQuantity(food, 2, 'katori')!;
      // 2 x 100 g at 129 kcal per 100 g
      expect(result.calories, closeTo(258, 0.001));
      expect(result.proteinG, closeTo(5.34, 0.001));
    });

    test('150 g of rice', () {
      final food = FoodItemModel.fromCatalog(riceRow());
      expect(XNutritionCalculator.forQuantity(food, 150, 'g')!.calories, closeTo(193.5, 0.001));
    });
  });

  group('FoodItemModel.unitLabel', () {
    test('explains the volume of katori, glass and cup', () {
      expect(FoodItemModel.unitLabel('katori'), 'katori (150 ml)');
      expect(FoodItemModel.unitLabel('glass'), 'glass (250 ml)');
      expect(FoodItemModel.unitLabel('cup'), 'cup (240 ml)');
      expect(FoodItemModel.unitLabel('piece'), 'piece');
    });
  });
}
