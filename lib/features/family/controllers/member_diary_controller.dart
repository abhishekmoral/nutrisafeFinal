import 'package:get/get.dart';

import '../../../data/repositories/family/family_repository.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../../nutrition/models/meal_entry_model.dart';
import '../../nutrition/models/nutrition_values.dart';
import '../models/diary_subject.dart';

/// -- The food diary of a family member (managed profile, or an adult who shared theirs).
class MemberDiaryController extends GetxController {
  MemberDiaryController({required this.subject});

  final DiarySubject subject;

  /// Variables
  final _repository = Get.put(FamilyRepository());
  final date = DateTime.now().obs;
  final entries = <MealEntryModel>[].obs;
  final loading = true.obs;

  NutritionValues get totals => entries.fold(NutritionValues.empty, (sum, e) => sum + e.nutrition);

  List<MealEntryModel> entriesFor(MealType meal) => entries.where((e) => e.mealType == meal).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      loading.value = true;
      entries.assignAll(await _repository.fetchEntries(subject, date.value));
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load the diary'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  void shiftDate(int days) {
    final next = date.value.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    date.value = next;
    load();
  }

  Future<void> changeQuantity(MealEntryModel entry, double quantity) async {
    if (!subject.canEdit || quantity <= 0) return;
    try {
      await _repository.updateEntryQuantity(entry, quantity);
      await load();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not change the amount'.tr, message: XExceptionHandler.message(e));
    }
  }

  Future<void> delete(MealEntryModel entry) async {
    if (!subject.canDelete || entry.id == null) return;
    try {
      await _repository.deleteEntry(entry.id!);
      await load();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not delete'.tr, message: XExceptionHandler.message(e));
    }
  }
}
