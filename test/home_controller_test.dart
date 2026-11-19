import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/nutrition/controllers/home_controller.dart';
import 'package:nutrisafe/features/nutrition/models/meal_entry_model.dart';
import 'package:nutrisafe/features/nutrition/models/nutrition_values.dart';
import 'package:nutrisafe/utils/constants/enums.dart';

MealEntryModel entry(String food, DateTime at, {double? kcal = 100}) => MealEntryModel(
      entryDate: DateTime(at.year, at.month, at.day),
      mealType: MealType.lunch,
      foodName: food,
      quantity: 1,
      unit: 'katori',
      consumedAt: at,
      nutrition: NutritionValues(calories: kcal),
    );

void main() {
  test('meal that fits the time of day', () {
    expect(HomeController.mealForTime(DateTime(2026, 11, 18, 8)), MealType.breakfast);
    expect(HomeController.mealForTime(DateTime(2026, 11, 18, 13)), MealType.lunch);
    expect(HomeController.mealForTime(DateTime(2026, 11, 18, 17)), MealType.snack);
    expect(HomeController.mealForTime(DateTime(2026, 11, 18, 21)), MealType.dinner);
  });

  test('streak counts back from today, or from yesterday when today is empty', () {
    final today = DateTime(2026, 11, 18);
    expect(HomeController.streak({'2026-11-18', '2026-11-17', '2026-11-16', '2026-11-14'}, today), 3);
    expect(HomeController.streak({'2026-11-17', '2026-11-16'}, today), 2);
    expect(HomeController.streak({'2026-11-15'}, today), 0);
    expect(HomeController.streak({'2026-11-01', '2026-10-31'}, DateTime(2026, 11, 1)), 2); // across months
  });

  test('recent foods: latest first, one per food, only foods with calories', () {
    final foods = HomeController.recent([
      entry('Dal chawal', DateTime(2026, 11, 16, 13)),
      entry('Poha', DateTime(2026, 11, 18, 8)),
      entry('dal chawal', DateTime(2026, 11, 17, 13)), // same food, newer
      entry('Homemade sabzi', DateTime(2026, 11, 18, 20), kcal: null), // unknown nutrition
    ]);
    expect(foods.map((f) => f.foodName), ['Poha', 'dal chawal']);
  });

  test('recent foods are limited', () {
    final many = [for (var i = 0; i < 20; i++) entry('Food $i', DateTime(2026, 11, 18, 0, i))];
    expect(HomeController.recent(many).length, 8);
  });
}
