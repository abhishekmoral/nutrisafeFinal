import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helpers/helper_function.dart';
import '../../../utils/localization/translations.dart';
import '../../nutrition/models/meal_entry_model.dart';
import '../../nutrition/models/nutrition_goal_model.dart';
import '../../nutrition/models/nutrition_values.dart';

/// Something the insights can chart and compare.
enum InsightMetric {
  calories('Calories', 'kcal', XColors.calories, isLimit: false),
  protein('Protein', 'g', XColors.protein, isLimit: false),
  carbs('Carbs', 'g', XColors.carbs, isLimit: false),
  fat('Fat', 'g', XColors.fat, isLimit: false),
  fiber('Fiber', 'g', XColors.fiber, isLimit: false),
  sugar('Sugar', 'g', XColors.secondary, isLimit: true),
  sodium('Sodium', 'mg', XColors.warning, isLimit: true),
  water('Water', 'ml', XColors.water, isLimit: false);

  const InsightMetric(this._label, this.unit, this.color, {required this.isLimit});

  final String _label;
  final String unit;
  final Color color;

  /// True when the goal is an upper limit (staying under it is the aim).
  final bool isLimit;

  String get label => _label.tr;

  /// Calories are a target, but going far over is not "better": compare both ways.
  bool get isTarget => this == InsightMetric.calories;

  double? valueOf(NutritionValues v) => switch (this) {
        calories => v.calories,
        protein => v.proteinG,
        carbs => v.carbsG,
        fat => v.fatG,
        fiber => v.fiberG,
        sugar => v.sugarG,
        sodium => v.sodiumMg,
        water => null, // water comes from the water log, not from foods
      };

  double? goalOf(NutritionGoalModel? g) => g == null
      ? null
      : switch (this) {
          calories => g.calories,
          protein => g.proteinG,
          carbs => g.carbsG,
          fat => g.fatG,
          fiber => g.fiberG,
          sugar => g.sugarG,
          sodium => g.sodiumMg,
          water => g.waterMl,
        };

  /// Was the goal met on a day with value [value]?
  /// Limits: at or under. Calories: within 10 % of the goal. Others: at or above.
  bool meets(double value, double goal) {
    if (isLimit) return value <= goal;
    if (isTarget) return (value - goal).abs() <= goal * 0.10;
    return value >= goal;
  }
}

/// How often one meal was logged and how much it brought.
class MealStat {
  const MealStat(this.meal, this.daysLogged, this.averageCalories);

  final MealType meal;
  final int daysLogged;
  final double? averageCalories; // per day the meal was logged
}

/// A food and how often / how much of a nutrient it brought in the period.
class FoodStat {
  const FoodStat(this.name, this.count, this.amount);

  final String name;
  final int count;
  final double amount; // of the metric it was ranked by (0 for "most logged")
}

/// -- Everything the Insights screen shows, calculated from the logged food and water of one period.
/// Pure Dart: no database, no widgets, so it is unit-tested.
/// Rules: days without a food entry are "not logged" and never count as zero; unknown nutrients
/// (null) are never counted as zero either.
class InsightsSummary {
  InsightsSummary({
    required this.from,
    required this.to,
    required List<MealEntryModel> entries,
    required Map<String, int> water,
  })  : entries = entries.where((e) => !_before(e.entryDate, from) && !_after(e.entryDate, to)).toList(),
        water = {
          for (final e in water.entries)
            if (!_before(DateTime.parse(e.key), from) && !_after(DateTime.parse(e.key), to)) e.key: e.value,
        } {
    for (final e in this.entries) {
      final key = XHelperFunctions.toDbDate(e.entryDate);
      totals[key] = (totals[key] ?? NutritionValues.empty) + e.nutrition;
    }
  }

  final DateTime from;
  final DateTime to;
  final List<MealEntryModel> entries;
  final Map<String, int> water; // yyyy-MM-dd -> ml
  final Map<String, NutritionValues> totals = {}; // only days with food entries

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  static bool _before(DateTime a, DateTime b) => _day(a).isBefore(_day(b));
  static bool _after(DateTime a, DateTime b) => _day(a).isAfter(_day(b));

  /// Every day of the period, oldest first.
  List<DateTime> get days {
    final out = <DateTime>[];
    for (var d = _day(from); !d.isAfter(_day(to)); d = DateTime(d.year, d.month, d.day + 1)) {
      out.add(d);
    }
    return out;
  }

  int get periodLength => days.length;
  int get loggedDays => totals.length;
  bool get isEmpty => totals.isEmpty && water.isEmpty;

  /// Value of [metric] on [day]; null when nothing (or nothing known) was logged.
  double? valueOn(InsightMetric metric, DateTime day) {
    final key = XHelperFunctions.toDbDate(day);
    if (metric == InsightMetric.water) return water[key]?.toDouble();
    final t = totals[key];
    return t == null ? null : metric.valueOf(t);
  }

  /// Daily values of [metric] on the days that have one.
  List<double> _values(InsightMetric metric) =>
      days.map((d) => valueOn(metric, d)).whereType<double>().toList();

  /// Average over the days that have a value (not over the whole period).
  double? average(InsightMetric metric) {
    final values = _values(metric);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Days that have a value for [metric].
  int daysWith(InsightMetric metric) => _values(metric).length;

  /// Days that met the goal, out of the days with a value. Null without a goal or data.
  ({int met, int of})? goalDays(InsightMetric metric, double? goal) {
    if (goal == null || goal <= 0) return null;
    final values = _values(metric);
    if (values.isEmpty) return null;
    return (met: values.where((v) => metric.meets(v, goal)).length, of: values.length);
  }

  /// The day with the highest value of [metric].
  ({DateTime day, double value})? best(InsightMetric metric) {
    ({DateTime day, double value})? top;
    for (final d in days) {
      final v = valueOn(metric, d);
      if (v != null && (top == null || v > top.value)) top = (day: d, value: v);
    }
    return top;
  }

  /// Consecutive days with food logged, ending today (or yesterday, if today is not logged yet).
  int streak(DateTime today) {
    var day = _day(today);
    if (!totals.containsKey(XHelperFunctions.toDbDate(day))) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (totals.containsKey(XHelperFunctions.toDbDate(day))) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Share of calories from protein, carbs and fat (4 / 4 / 9 kcal per gram), from the average day.
  ({double protein, double carbs, double fat})? get macroSplit {
    double sum(InsightMetric m) => _values(m).fold(0.0, (a, b) => a + b);
    final p = sum(InsightMetric.protein) * 4;
    final c = sum(InsightMetric.carbs) * 4;
    final f = sum(InsightMetric.fat) * 9;
    final total = p + c + f;
    if (total <= 0) return null;
    return (protein: p / total, carbs: c / total, fat: f / total);
  }

  /// How often each meal was logged, and its average calories on those days.
  List<MealStat> get mealStats {
    return MealType.values.map((meal) {
      final byDay = <String, double?>{};
      for (final e in entries.where((e) => e.mealType == meal)) {
        final key = XHelperFunctions.toDbDate(e.entryDate);
        final kcal = e.nutrition.calories;
        byDay[key] = kcal == null ? byDay[key] : (byDay[key] ?? 0) + kcal;
        byDay.putIfAbsent(key, () => null);
      }
      final known = byDay.values.whereType<double>().toList();
      return MealStat(
        meal,
        byDay.length,
        known.isEmpty ? null : known.reduce((a, b) => a + b) / known.length,
      );
    }).toList();
  }

  /// Foods logged most often.
  List<FoodStat> topFoods({int limit = 5}) {
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final e in entries) {
      final key = e.foodName.trim().toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
      names.putIfAbsent(key, () => e.foodName.trim());
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => FoodStat(names[e.key]!, e.value, 0)).toList();
  }

  /// Foods that brought the most of [metric] in the period.
  List<FoodStat> topSources(InsightMetric metric, {int limit = 3}) {
    final sums = <String, double>{};
    final counts = <String, int>{};
    final names = <String, String>{};
    for (final e in entries) {
      final v = metric.valueOf(e.nutrition);
      if (v == null || v <= 0) continue;
      final key = e.foodName.trim().toLowerCase();
      sums[key] = (sums[key] ?? 0) + v;
      counts[key] = (counts[key] ?? 0) + 1;
      names.putIfAbsent(key, () => e.foodName.trim());
    }
    final sorted = sums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => FoodStat(names[e.key]!, counts[e.key]!, e.value)).toList();
  }

  /// Entries without calorie values (their nutrition is unknown, so totals are a lower bound).
  int get entriesWithoutNutrition => entries.where((e) => e.nutrition.calories == null).length;

  /// Change of the average against an earlier period, in percent (null when either is unknown).
  static double? change(double? now, double? before) {
    if (now == null || before == null || before == 0) return null;
    return (now - before) / before * 100;
  }

  /// Short facts calculated from the period (not advice, not AI).
  List<String> highlights(NutritionGoalModel? goals, {InsightsSummary? previous}) {
    final out = <String>[];
    String n(double v) => XHelperFunctions.formatNumber(v, decimals: 0);
    String day(DateTime d) => XHelperFunctions.dayLabel(d);

    if (loggedDays == 0) return out;
    if (loggedDays < periodLength) {
      out.add('Food logged on {logged} of {days} days. Insights are more accurate when every day is logged.'
          .trf({'logged': loggedDays, 'days': periodLength}));
    }

    final protein = best(InsightMetric.protein);
    if (protein != null && loggedDays > 1) {
      out.add('Most protein: {value} g on {day}.'.trf({'value': n(protein.value), 'day': day(protein.day)}));
    }

    for (final metric in [InsightMetric.sodium, InsightMetric.sugar]) {
      final g = goalDays(metric, metric.goalOf(goals));
      if (g != null && g.met < g.of) {
        out.add('{nutrient} was above your limit on {over} of {days} logged days.'
            .trf({'nutrient': metric.label, 'over': g.of - g.met, 'days': g.of}));
      }
    }

    final fiber = goalDays(InsightMetric.fiber, goals?.fiberG);
    if (fiber != null && fiber.met == 0) {
      out.add('Your fiber goal was not reached on any logged day. Dal, whole grains, fruit and vegetables add fiber.'.tr);
    }

    final water = goalDays(InsightMetric.water, goals?.waterMl);
    if (water != null) {
      out.add('Water goal reached on {met} of {days} days with water logged.'.trf({'met': water.met, 'days': water.of}));
    }

    final skipped = mealStats.where((m) => m.meal != MealType.snack && m.daysLogged < loggedDays / 2).toList();
    for (final m in skipped) {
      out.add('{meal} was logged on only {count} of {days} days.'
          .trf({'meal': m.meal.label, 'count': m.daysLogged, 'days': loggedDays}));
    }

    if (previous != null && previous.loggedDays > 0) {
      for (final metric in [InsightMetric.protein, InsightMetric.fiber, InsightMetric.sugar, InsightMetric.sodium]) {
        final c = change(average(metric), previous.average(metric));
        if (c != null && c.abs() >= 15) {
          out.add((c > 0 ? 'Average {nutrient} is up {percent}% from the previous period.' : 'Average {nutrient} is down {percent}% from the previous period.')
              .trf({'nutrient': metric.label.toLowerCase(), 'percent': n(c.abs())}));
        }
      }
    }

    if (entriesWithoutNutrition > 0) {
      out.add('{count} logged item(s) have no nutrition values, so totals may be lower than what you ate.'
          .trf({'count': entriesWithoutNutrition}));
    }
    return out;
  }
}
