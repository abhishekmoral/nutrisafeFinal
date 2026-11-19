import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/food/food_repository.dart';
import '../../../data/repositories/water/water_repository.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helpers/helper_function.dart';
import '../../../utils/localization/translations.dart';
import '../../../utils/popups/loaders.dart';
import '../models/meal_entry_model.dart';
import 'food_diary_controller.dart';

/// -- Data for the home screen that is not "today": the last 7 days (week strip, streak)
/// and recently eaten foods that can be logged again with one tap.
class HomeController extends GetxController {
  /// Created on first use, so Home also works after a hot reload (which does not re-run the
  /// navigation setup that normally creates it).
  static HomeController get instance =>
      Get.isRegistered<HomeController>() ? Get.find() : Get.put(HomeController(), permanent: true);

  final _foodRepository = Get.put(FoodRepository());
  final _waterRepository = Get.put(WaterRepository());

  /// Days before today (yyyy-MM-dd) that have food logged, within the last 30 days.
  final loggedDays = <String>{}.obs;
  final waterDays = <String, int>{}.obs;
  final recentFoods = <MealEntryModel>[].obs; // one per food, most recent first
  final relogging = RxnString(); // food name being added again

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final from = DateTime(today.year, today.month, today.day - 30);
      final results = await Future.wait([
        _foodRepository.fetchEntriesBetween(from, today),
        _waterRepository.fetchDailyTotals(from, today),
      ]);
      final entries = results[0] as List<MealEntryModel>;
      loggedDays.assignAll(entries.map((e) => XHelperFunctions.toDbDate(e.entryDate)));
      waterDays.assignAll(results[1] as Map<String, int>);
      recentFoods.assignAll(recent(entries));
    } catch (_) {
      // The week strip and "log again" are extras; the rest of home still works.
    }
  }

  /// One entry per food (latest first), only foods with known calories, at most [limit].
  static List<MealEntryModel> recent(List<MealEntryModel> entries, {int limit = 8}) {
    final sorted = [...entries]..sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    final seen = <String>{};
    final out = <MealEntryModel>[];
    for (final e in sorted) {
      final key = e.foodName.trim().toLowerCase();
      if (e.nutrition.calories == null || !seen.add(key)) continue;
      out.add(e);
      if (out.length == limit) break;
    }
    return out;
  }

  /// The meal that fits the time of day.
  static MealType mealForTime(DateTime time) {
    final h = time.hour;
    if (h < 11) return MealType.breakfast;
    if (h < 16) return MealType.lunch;
    if (h < 19) return MealType.snack;
    return MealType.dinner;
  }

  /// Consecutive days with food logged, ending today (or yesterday when today is still empty).
  static int streak(Set<String> logged, DateTime today) {
    var day = DateTime(today.year, today.month, today.day);
    if (!logged.contains(XHelperFunctions.toDbDate(day))) day = DateTime(day.year, day.month, day.day - 1);
    var count = 0;
    while (logged.contains(XHelperFunctions.toDbDate(day))) {
      count++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return count;
  }

  /// Logged days including today's live diary.
  Set<String> loggedIncludingToday() {
    final today = DateTime.now();
    final days = {...loggedDays};
    final key = XHelperFunctions.toDbDate(today);
    FoodDiaryController.instance.entriesOn(today).isEmpty ? days.remove(key) : days.add(key);
    return days;
  }

  /// Adds the same food and amount again, today, to [meal].
  Future<void> logAgain(MealEntryModel food, MealType meal) async {
    if (relogging.value != null) return;
    relogging.value = food.foodName;
    try {
      final now = DateTime.now();
      final entry = MealEntryModel(
        entryDate: DateTime(now.year, now.month, now.day),
        mealType: meal,
        foodId: food.foodId,
        foodName: food.foodName,
        quantity: food.quantity,
        unit: food.unit,
        consumedAt: now,
        nutrition: food.nutrition,
        entrySource: food.entrySource,
        quality: food.quality,
        clientEntryId: const Uuid().v4(),
      );
      final saved = await FoodDiaryController.instance.addEntry(entry);
      if (saved) {
        loggedDays.add(XHelperFunctions.toDbDate(now));
        XLoaders.successSnackBar(
          title: 'Added to {label}'.trf({'label': meal.label}),
          message: '${food.foodName} · ${food.quantityLabel}',
        );
      }
    } finally {
      relogging.value = null;
    }
  }
}
