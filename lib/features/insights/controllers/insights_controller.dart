import 'package:get/get.dart';

import '../../../data/repositories/food/food_repository.dart';
import '../../../data/repositories/water/water_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../../nutrition/models/meal_entry_model.dart';
import '../models/insights_summary.dart';

/// -- Analytics calculated from what the user logged: the chosen period and the one before it.
class InsightsController extends GetxController {
  static InsightsController get instance => Get.find();

  static const periods = [7, 14, 30];

  /// Variables
  final _foodRepository = Get.put(FoodRepository());
  final _waterRepository = Get.put(WaterRepository());
  final loading = true.obs;
  final periodDays = 7.obs;
  final metric = InsightMetric.calories.obs; // shown in the daily chart
  final selectedDay = Rxn<DateTime>(); // bar tapped in the chart
  final current = Rxn<InsightsSummary>();
  final previous = Rxn<InsightsSummary>(); // the same number of days just before
  int _loadToken = 0;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> setPeriod(int days) async {
    if (days == periodDays.value) return;
    periodDays.value = days;
    selectedDay.value = null;
    await load();
  }

  void selectDay(DateTime? day) =>
      selectedDay.value = (day != null && selectedDay.value == day) ? null : day;

  Future<void> load() async {
    final token = ++_loadToken;
    if (current.value == null) loading.value = true;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final n = periodDays.value;
      final from = DateTime(today.year, today.month, today.day - (n - 1));
      final previousFrom = DateTime(from.year, from.month, from.day - n);
      final previousTo = DateTime(from.year, from.month, from.day - 1);

      // One request each for both periods.
      final results = await Future.wait([
        _foodRepository.fetchEntriesBetween(previousFrom, today),
        _waterRepository.fetchDailyTotals(previousFrom, today),
      ]);
      if (token != _loadToken) return; // a newer period was chosen meanwhile
      final entries = results[0] as List<MealEntryModel>;
      final water = results[1] as Map<String, int>;
      current.value = InsightsSummary(from: from, to: today, entries: entries, water: water);
      previous.value = InsightsSummary(from: previousFrom, to: previousTo, entries: entries, water: water);
    } catch (e) {
      if (token == _loadToken) {
        XLoaders.errorSnackBar(title: 'Could not load insights'.tr, message: XExceptionHandler.message(e));
      }
    } finally {
      if (token == _loadToken) loading.value = false;
    }
  }
}
