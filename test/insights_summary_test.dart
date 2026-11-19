import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/insights/models/insights_summary.dart';
import 'package:nutrisafe/features/nutrition/models/meal_entry_model.dart';
import 'package:nutrisafe/features/nutrition/models/nutrition_goal_model.dart';
import 'package:nutrisafe/features/nutrition/models/nutrition_values.dart';
import 'package:nutrisafe/utils/constants/enums.dart';

MealEntryModel entry(DateTime day, String food, MealType meal, NutritionValues n) => MealEntryModel(
      entryDate: day,
      mealType: meal,
      foodName: food,
      quantity: 1,
      unit: 'serving',
      consumedAt: day,
      nutrition: n,
    );

void main() {
  final today = DateTime(2026, 11, 18);
  DateTime d(int daysAgo) => DateTime(today.year, today.month, today.day - daysAgo);
  final from = d(6);

  // Logged: today, yesterday, 2 days ago and 5 days ago (4 of 7 days).
  final entries = [
    entry(d(0), 'Poha', MealType.breakfast, const NutritionValues(calories: 300, proteinG: 6, carbsG: 50, fatG: 8, fiberG: 3, sugarG: 4, sodiumMg: 600)),
    entry(d(0), 'Dal chawal', MealType.lunch, const NutritionValues(calories: 500, proteinG: 18, carbsG: 80, fatG: 10, fiberG: 8, sugarG: 2, sodiumMg: 900)),
    entry(d(0), 'Parle-G', MealType.snack, const NutritionValues(calories: 115, proteinG: 1.7, carbsG: 19, fatG: 3.3, sugarG: 6, sodiumMg: 73)),
    entry(d(1), 'Dal chawal', MealType.lunch, const NutritionValues(calories: 500, proteinG: 18, carbsG: 80, fatG: 10, fiberG: 8, sugarG: 2, sodiumMg: 900)),
    entry(d(1), 'Paneer roti', MealType.dinner, const NutritionValues(calories: 600, proteinG: 30, carbsG: 60, fatG: 25, fiberG: 5, sugarG: 3, sodiumMg: 1200)),
    entry(d(2), 'Dal chawal', MealType.lunch, const NutritionValues(calories: 500, proteinG: 18, carbsG: 80, fatG: 10, fiberG: 8, sugarG: 2, sodiumMg: 900)),
    entry(d(2), 'Homemade sabzi', MealType.dinner, NutritionValues.empty), // unknown nutrition
    entry(d(5), 'Samosa', MealType.snack, const NutritionValues(calories: 260, proteinG: 4, carbsG: 30, fatG: 14, sodiumMg: 450)),
    // Outside the period: must be ignored.
    entry(d(7), 'Old entry', MealType.lunch, const NutritionValues(calories: 9999)),
  ];
  final water = {'2026-11-18': 2000, '2026-11-17': 1500, '2026-11-10': 3000};
  final s = InsightsSummary(from: from, to: today, entries: entries, water: water);

  final goals = NutritionGoalModel(calories: 1800, proteinG: 50, fiberG: 25, sugarG: 30, sodiumMg: 2000, waterMl: 2000);

  test('period and logged days; entries outside the period are left out', () {
    expect(s.periodLength, 7);
    expect(s.days.first, from);
    expect(s.loggedDays, 4);
    expect(s.entries.any((e) => e.foodName == 'Old entry'), isFalse);
    expect(s.water.containsKey('2026-11-10'), isFalse);
  });

  test('averages use only the days with a value (unlogged days are not zero)', () {
    // Calories per day: 915, 1100, 500, 260 -> 2775 / 4.
    expect(s.average(InsightMetric.calories), closeTo(693.75, 0.01));
    // Fiber known on 3 days: 11, 13, 8 (the samosa day has no fiber value).
    expect(s.daysWith(InsightMetric.fiber), 3);
    expect(s.average(InsightMetric.water), 1750);
  });

  test('daily values and unknown days', () {
    expect(s.valueOn(InsightMetric.calories, d(0)), 915);
    expect(s.valueOn(InsightMetric.calories, d(3)), isNull);
    expect(s.valueOn(InsightMetric.water, d(1)), 1500);
  });

  test('streak counts back from today', () {
    expect(s.streak(today), 3);
    // If today is not logged yet, the streak still counts up to yesterday.
    final noToday = InsightsSummary(from: from, to: today, entries: entries.where((e) => e.entryDate != d(0)).toList(), water: const {});
    expect(noToday.streak(today), 2);
  });

  test('goal days: targets, limits and calories within 10 %', () {
    expect(s.goalDays(InsightMetric.protein, 50), (met: 0, of: 4));
    expect(s.goalDays(InsightMetric.sodium, 2000), (met: 3, of: 4)); // 2100 mg on yesterday
    expect(s.goalDays(InsightMetric.water, 2000), (met: 1, of: 2));
    expect(s.goalDays(InsightMetric.calories, 1000), (met: 2, of: 4)); // 915 and 1100 are within 10 %
    expect(s.goalDays(InsightMetric.fiber, null), isNull);
  });

  test('best day', () {
    final best = s.best(InsightMetric.protein)!;
    expect(best.day, d(1));
    expect(best.value, 48);
  });

  test('macro split adds up to 100 %', () {
    final m = s.macroSplit!;
    expect(m.protein + m.carbs + m.fat, closeTo(1, 0.0001));
    expect(m.carbs, greaterThan(m.protein));
  });

  test('meal pattern', () {
    final lunch = s.mealStats.firstWhere((m) => m.meal == MealType.lunch);
    expect(lunch.daysLogged, 3);
    expect(lunch.averageCalories, 500);
    final breakfast = s.mealStats.firstWhere((m) => m.meal == MealType.breakfast);
    expect(breakfast.daysLogged, 1);
    final dinner = s.mealStats.firstWhere((m) => m.meal == MealType.dinner);
    expect(dinner.daysLogged, 2);
    expect(dinner.averageCalories, 600); // the sabzi day has no calories and is not averaged in
  });

  test('top foods and top sources', () {
    expect(s.topFoods().first.name, 'Dal chawal');
    expect(s.topFoods().first.count, 3);
    final sodium = s.topSources(InsightMetric.sodium);
    expect(sodium.first.name, 'Dal chawal');
    expect(sodium.first.amount, 2700);
    expect(sodium.length, 3);
  });

  test('entries without nutrition are counted', () {
    expect(s.entriesWithoutNutrition, 1);
  });

  test('change against the previous period', () {
    expect(InsightsSummary.change(120, 100), closeTo(20, 0.001));
    expect(InsightsSummary.change(80, 100), closeTo(-20, 0.001));
    expect(InsightsSummary.change(null, 100), isNull);
    expect(InsightsSummary.change(50, 0), isNull);
  });

  test('highlights are calculated facts', () {
    final previous = InsightsSummary(
      from: d(13),
      to: d(7),
      entries: [entry(d(8), 'Dal', MealType.lunch, const NutritionValues(calories: 400, proteinG: 15, fiberG: 6, sugarG: 2, sodiumMg: 500))],
      water: const {},
    );
    final h = s.highlights(goals, previous: previous);
    expect(h.any((t) => t.contains('4 of 7 days')), isTrue);
    expect(h.any((t) => t.contains('Most protein: 48 g')), isTrue);
    expect(h.any((t) => t.startsWith('Sodium was above your limit on 1 of 4')), isTrue);
    expect(h.any((t) => t.contains('fiber goal was not reached')), isTrue);
    expect(h.any((t) => t.startsWith('Breakfast was logged on only 1 of 4')), isTrue);
    expect(h.any((t) => t.contains('protein is up')), isTrue);
    expect(h.any((t) => t.contains('1 logged item(s) have no nutrition values')), isTrue);
  });

  test('empty period', () {
    final empty = InsightsSummary(from: from, to: today, entries: const [], water: const {});
    expect(empty.isEmpty, isTrue);
    expect(empty.average(InsightMetric.calories), isNull);
    expect(empty.macroSplit, isNull);
    expect(empty.highlights(goals), isEmpty);
    expect(empty.streak(today), 0);
  });

  test('metric goal rules', () {
    expect(InsightMetric.sodium.meets(1900, 2000), isTrue);
    expect(InsightMetric.sodium.meets(2100, 2000), isFalse);
    expect(InsightMetric.protein.meets(50, 50), isTrue);
    expect(InsightMetric.calories.meets(2100, 1800), isFalse);
    expect(InsightMetric.calories.meets(1700, 1800), isTrue);
  });
}
