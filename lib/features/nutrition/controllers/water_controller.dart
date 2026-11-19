import 'package:get/get.dart';

import '../../../data/repositories/water/water_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import 'food_diary_controller.dart';

class WaterController extends GetxController {
  static WaterController get instance => Get.find();

  /// Variables
  static const quickAmounts = [150, 250, 500, 750];
  final _waterRepository = Get.put(WaterRepository());
  final todayLogs = <Map<String, dynamic>>[].obs;
  final weekTotals = <String, int>{}.obs; // yyyy-MM-dd -> ml
  final saving = false.obs;

  int get todayTotal => todayLogs.fold(0, (sum, log) => sum + (log['amount_ml'] as num).toInt());

  /// The user's own adjustable target; null when they have not set one.
  double? get targetMl => FoodDiaryController.instance.goals.value?.waterMl;

  double get progress {
    final target = targetMl;
    if (target == null || target <= 0) return 0;
    return (todayTotal / target).clamp(0, 1).toDouble();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final today = DateTime.now();
      final results = await Future.wait([
        _waterRepository.fetchLogs(today),
        _waterRepository.fetchDailyTotals(today.subtract(const Duration(days: 6)), today),
      ]);
      todayLogs.assignAll(results[0] as List<Map<String, dynamic>>);
      weekTotals.assignAll(results[1] as Map<String, int>);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load water'.tr, message: XExceptionHandler.message(e));
    }
  }

  Future<void> addWater(int amountMl) async {
    if (saving.value || amountMl <= 0 || amountMl > 5000) return;
    try {
      saving.value = true;
      await _waterRepository.addLog(DateTime.now(), amountMl);
      await load();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save water'.tr, message: XExceptionHandler.message(e));
    } finally {
      saving.value = false;
    }
  }

  Future<void> deleteLog(String id) async {
    try {
      await _waterRepository.deleteLog(id);
      await load();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not delete'.tr, message: XExceptionHandler.message(e));
    }
  }
}
