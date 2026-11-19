import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/food/food_repository.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/helpers/helper_function.dart';
import '../../../utils/popups/loaders.dart';
import '../models/meal_entry_model.dart';
import '../models/nutrition_goal_model.dart';
import '../models/nutrition_values.dart';

/// -- Food diary state shared by the Home dashboard and the Food tab.
class FoodDiaryController extends GetxController {
  static FoodDiaryController get instance => Get.find();

  /// Variables
  final _foodRepository = Get.put(FoodRepository());
  final selectedDate = DateTime.now().obs;
  final entriesByDay = <String, List<MealEntryModel>>{}.obs; // key = yyyy-MM-dd
  final goals = Rxn<NutritionGoalModel>();
  final loading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadGoals();
    final now = DateTime.now();
    loadDay(now);
    loadDay(DateTime(now.year, now.month, now.day - 1), quiet: true); // for "copy from yesterday"
  }

  /// -- Entries
  List<MealEntryModel> entriesOn(DateTime date) =>
      entriesByDay[XHelperFunctions.toDbDate(date)] ?? const [];

  List<MealEntryModel> entriesFor(DateTime date, MealType meal) =>
      entriesOn(date).where((e) => e.mealType == meal).toList();

  /// Calculated from the saved entries (unknown nutrients are not counted).
  NutritionValues totalsOn(DateTime date) =>
      entriesOn(date).fold(NutritionValues.empty, (sum, e) => sum + e.nutrition);

  NutritionValues totalsFor(DateTime date, MealType meal) =>
      entriesFor(date, meal).fold(NutritionValues.empty, (sum, e) => sum + e.nutrition);

  /// How many entries of the day have no calorie value at all.
  int unknownCaloriesCount(DateTime date) =>
      entriesOn(date).where((e) => e.nutrition.calories == null).length;

  /// [quiet]: a background load (e.g. yesterday for "copy from yesterday") shows no error.
  Future<void> loadDay(DateTime date, {bool quiet = false}) async {
    try {
      if (!quiet) loading.value = true;
      final entries = await _foodRepository.fetchEntries(date);
      entriesByDay[XHelperFunctions.toDbDate(date)] = entries;
    } catch (e) {
      if (!quiet) XLoaders.errorSnackBar(title: 'Could not load diary'.tr, message: XExceptionHandler.message(e));
    } finally {
      if (!quiet) loading.value = false;
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([loadGoals(), loadDay(DateTime.now()), loadDay(selectedDate.value)]);
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
    loadDay(date);
    // The day before is needed for "copy from yesterday".
    loadDay(DateTime(date.year, date.month, date.day - 1), quiet: true);
  }

  void shiftDate(int days) {
    final next = selectedDate.value.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    changeDate(next);
  }

  /// -- Save an entry the user confirmed. Returns true on success.
  Future<bool> addEntry(MealEntryModel entry) async {
    try {
      await _foodRepository.addEntry(entry);
      await loadDay(entry.entryDate);
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save food'.tr, message: XExceptionHandler.message(e));
      return false;
    }
  }

  /// Takes an entry off the screen right away (the delete itself follows).
  void hideEntry(MealEntryModel entry) {
    final key = XHelperFunctions.toDbDate(entry.entryDate);
    entriesByDay[key] = entriesOn(entry.entryDate).where((e) => e.id != entry.id).toList();
  }

  Future<void> deleteEntry(MealEntryModel entry) async {
    if (entry.id == null) return;
    try {
      await _foodRepository.deleteEntry(entry.id!);
      await loadDay(entry.entryDate);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not delete'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// -- Change the amount; nutrition scales with it (it was calculated from the amount).
  Future<bool> changeQuantity(MealEntryModel entry, double quantity) async {
    if (entry.id == null || quantity <= 0 || entry.quantity <= 0) return false;
    try {
      await _foodRepository.updateEntry(
        entry.id!,
        quantity: quantity,
        nutrition: entry.nutrition.scale(quantity / entry.quantity),
      );
      await loadDay(entry.entryDate);
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not update'.tr, message: XExceptionHandler.message(e));
      return false;
    }
  }

  /// -- Move an entry to another meal of the same day.
  Future<bool> moveEntry(MealEntryModel entry, MealType meal) async {
    if (entry.id == null || entry.mealType == meal) return false;
    try {
      await _foodRepository.updateEntry(entry.id!, mealType: meal);
      await loadDay(entry.entryDate);
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not update'.tr, message: XExceptionHandler.message(e));
      return false;
    }
  }

  /// A new entry with the same food and amount, on [date] (and [meal], if given).
  static MealEntryModel copyOf(MealEntryModel entry, DateTime date, {MealType? meal}) {
    final day = DateTime(date.year, date.month, date.day);
    final time = entry.consumedAt;
    return MealEntryModel(
      entryDate: day,
      mealType: meal ?? entry.mealType,
      foodId: entry.foodId,
      foodName: entry.foodName,
      quantity: entry.quantity,
      unit: entry.unit,
      consumedAt: DateTime(day.year, day.month, day.day, time.hour, time.minute),
      nutrition: entry.nutrition,
      entrySource: entry.entrySource,
      quality: entry.quality,
      clientEntryId: const Uuid().v4(),
    );
  }

  /// -- Copy entries to another day. Returns how many were saved.
  Future<int> copyEntries(List<MealEntryModel> entries, DateTime toDate, {MealType? meal}) async {
    var saved = 0;
    try {
      for (final e in entries) {
        await _foodRepository.addEntry(copyOf(e, toDate, meal: meal));
        saved++;
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not copy'.tr, message: XExceptionHandler.message(e));
    }
    await loadDay(toDate);
    return saved;
  }

  /// Entries of the day before [date] (loaded if needed), for "copy from yesterday".
  Future<List<MealEntryModel>> previousDayEntries(DateTime date) async {
    final previous = DateTime(date.year, date.month, date.day - 1);
    if (!entriesByDay.containsKey(XHelperFunctions.toDbDate(previous))) await loadDay(previous, quiet: true);
    return entriesOn(previous);
  }

  /// -- Delete with an undo: the removed entry is saved again as a copy.
  Future<void> undoDelete(MealEntryModel entry) async {
    await addEntry(copyOf(entry, entry.entryDate));
  }

  /// -- Goals
  Future<void> loadGoals() async {
    try {
      goals.value = await _foodRepository.fetchGoals();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load goals'.tr, message: XExceptionHandler.message(e));
    }
  }

  Future<bool> saveGoals(NutritionGoalModel updated) async {
    try {
      await _foodRepository.saveGoals(updated);
      goals.value = updated;
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save goals'.tr, message: XExceptionHandler.message(e));
      return false;
    }
  }
}
