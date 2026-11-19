import 'dart:async';

import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../data/repositories/family/family_repository.dart';
import '../../../data/repositories/food/food_repository.dart';
import '../../family/models/diary_subject.dart';
import '../../../data/repositories/user/user_repository.dart';
import '../../../data/services/open_food_facts_service.dart';
import '../../../data/services/product_lookup_service.dart';
import '../../../utils/helpers/allergen_words.dart';
import '../models/product_draft.dart';
import '../models/scanned_barcode.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/food_item_model.dart';
import '../models/meal_entry_model.dart';
import '../models/nutrition_values.dart';
import 'food_diary_controller.dart';
import '../../../utils/localization/translations.dart';

class AddFoodController extends GetxController {
  AddFoodController({required this.mealType, required this.date, this.subject});

  static AddFoodController get instance => Get.find();

  /// Variables
  final MealType mealType;
  final DateTime date;
  final DiarySubject? subject; // null = my own diary; otherwise a family member's diary
  final _foodRepository = Get.put(FoodRepository());
  final _userRepository = Get.put(UserRepository());

  final catalogResults = <FoodItemModel>[].obs;
  final productResults = <FoodItemModel>[].obs;
  final searching = false.obs;
  final searchedOnce = false.obs;
  final productSearchError = RxnString();
  final saving = false.obs;
  final userAllergens = <String>[].obs;
  bool scanOpened = false; // the scanner auto-opens only once per screen
  Timer? _debounce;
  int _searchToken = 0;

  @override
  void onInit() {
    super.onInit();
    _loadAllergens();
  }

  /// "your allergen" or "Aarav's allergen" in warnings.
  String get allergenOwnerLabel => subject == null ? 'your allergen'.tr : '{name}\'s allergen'.trf({'name': subject!.name});

  Future<void> _loadAllergens() async {
    try {
      final s = subject;
      userAllergens.assignAll(
        s == null
            ? await _userRepository.fetchAllergies()
            : await Get.put(FamilyRepository()).fetchAllergies(ownerId: s.ownerId, childId: s.childId),
      );
    } catch (_) {
      // Allergen warnings are a helper; the screen still works without them.
    }
  }

  /// -- Search (debounced)
  void onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => search(query));
  }

  Future<void> search(String query) async {
    final text = query.trim();
    final token = ++_searchToken;
    if (text.length < 2) {
      catalogResults.clear();
      productResults.clear();
      searchedOnce.value = false;
      return;
    }
    searching.value = true;
    productSearchError.value = null;

    // Curated catalog first (fast), then packaged products from Open Food Facts.
    try {
      final catalog = await _foodRepository.searchCatalog(text);
      if (token == _searchToken) catalogResults.assignAll(catalog);
    } catch (e) {
      if (token == _searchToken) catalogResults.clear();
    }
    try {
      final products = await OpenFoodFactsService.searchProducts(text);
      if (token == _searchToken) productResults.assignAll(products);
    } catch (e) {
      if (token == _searchToken) {
        productResults.clear();
        productSearchError.value = 'Packaged product search is unavailable right now.'.tr;
      }
    }
    if (token == _searchToken) {
      searching.value = false;
      searchedOnce.value = true;
    }
  }

  /// -- Barcode lookup in every product database (NutriSafe, Open Food Facts, USDA, Nutritionix, FatSecret).
  /// Returns null only when the search itself failed (offline, server down); the error is shown.
  /// A product that no database knows comes back with status "not_found".
  Future<ProductDraft?> lookupBarcode(ScannedBarcode scan) async {
    try {
      return await ProductLookupService.lookup(scan.code, format: scan.format);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not search for the product'.tr, message: XExceptionHandler.message(e));
      return null;
    }
  }

  /// -- Allergens of the user that appear in this food's label data.
  /// An empty list does NOT mean the food is safe.
  List<String> matchingAllergens(FoodItemModel food) {
    final haystack = [
      food.name,
      food.ingredientsText ?? '',
      ...food.allergens,
    ].join(' ');
    // Also catches label words such as maida (wheat), ghee (milk) or kaju (tree nuts).
    return userAllergens.where((allergen) => XAllergenWords.mentions(haystack, allergen)).toList();
  }

  /// -- Save after the user confirmed quantity (and nutrition for manual entries).
  Future<bool> saveEntry({
    required FoodItemModel food,
    required double quantity,
    required String unit,
    required NutritionValues nutrition,
    required NutritionQuality quality,
  }) async {
    if (saving.value) return false;
    saving.value = true;
    final now = DateTime.now();
    final entry = MealEntryModel(
      entryDate: date,
      mealType: mealType,
      foodId: food.foodId,
      foodName: food.brand == null || food.brand!.isEmpty ? food.name : '${food.name} (${food.brand})',
      quantity: quantity,
      unit: unit,
      consumedAt: DateTime(date.year, date.month, date.day, now.hour, now.minute),
      nutrition: nutrition,
      entrySource: food.entrySource,
      quality: quality,
      clientEntryId: const Uuid().v4(),
    );
    final s = subject;
    if (s == null) {
      final saved = await FoodDiaryController.instance.addEntry(entry);
      saving.value = false;
      return saved;
    }
    try {
      await Get.put(FamilyRepository()).addEntry(s, entry);
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save food'.tr, message: XExceptionHandler.message(e));
      return false;
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
