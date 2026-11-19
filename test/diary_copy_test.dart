import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/nutrition/controllers/food_diary_controller.dart';
import 'package:nutrisafe/features/nutrition/models/meal_entry_model.dart';
import 'package:nutrisafe/features/nutrition/models/nutrition_values.dart';
import 'package:nutrisafe/utils/constants/enums.dart';

void main() {
  final original = MealEntryModel(
    id: 'abc',
    entryDate: DateTime(2026, 11, 17),
    mealType: MealType.breakfast,
    foodId: 'food-1',
    foodName: 'Poha',
    quantity: 1.5,
    unit: 'katori',
    consumedAt: DateTime(2026, 11, 17, 8, 30),
    nutrition: const NutritionValues(calories: 270, proteinG: 5),
    entrySource: 'catalog',
    quality: NutritionQuality.calculated,
    clientEntryId: 'old-id',
  );

  test('a copy keeps the food, amount, nutrition and time of day, on the new date', () {
    final copy = FoodDiaryController.copyOf(original, DateTime(2026, 11, 18, 21, 5));
    expect(copy.id, isNull); // a new row
    expect(copy.entryDate, DateTime(2026, 11, 18));
    expect(copy.consumedAt, DateTime(2026, 11, 18, 8, 30));
    expect(copy.mealType, MealType.breakfast);
    expect(copy.foodName, 'Poha');
    expect(copy.quantity, 1.5);
    expect(copy.unit, 'katori');
    expect(copy.nutrition.calories, 270);
    expect(copy.foodId, 'food-1');
    expect(copy.quality, NutritionQuality.calculated);
  });

  test('every copy gets its own client id, so a retried save is not a duplicate of the original', () {
    final a = FoodDiaryController.copyOf(original, DateTime(2026, 11, 18));
    final b = FoodDiaryController.copyOf(original, DateTime(2026, 11, 18));
    expect(a.clientEntryId, isNot('old-id'));
    expect(a.clientEntryId, isNot(b.clientEntryId));
  });

  test('a copy can go to another meal', () {
    expect(FoodDiaryController.copyOf(original, DateTime(2026, 11, 18), meal: MealType.snack).mealType, MealType.snack);
  });
}
