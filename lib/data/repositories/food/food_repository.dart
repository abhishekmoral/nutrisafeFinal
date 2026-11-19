import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/nutrition/models/food_item_model.dart';
import '../../../features/nutrition/models/meal_entry_model.dart';
import '../../../features/nutrition/models/nutrition_goal_model.dart';
import '../../../features/nutrition/models/nutrition_values.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/helpers/food_search.dart';
import '../../../utils/helpers/helper_function.dart';

class FoodRepository extends GetxController {
  static FoodRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  String get _uid => _supabase.auth.currentUser!.id;

  /// -- Save a packaged product the person checked (one copy per barcode; saving again updates it).
  /// Returns the product id. Next scans of the barcode find it straight away.
  Future<String> saveConfirmedProduct(Map<String, dynamic> product) async {
    final id = await _supabase.rpc('save_confirmed_product', params: {'p': product});
    return id as String;
  }

  /// -- Change an entry's amount (nutrition is given already scaled) and/or its meal.
  Future<void> updateEntry(String id, {double? quantity, NutritionValues? nutrition, MealType? mealType}) async {
    await _supabase.from('meal_entries').update({
      'quantity': ?quantity,
      ...?nutrition?.toJson(),
      'meal_type': ?mealType?.value,
    }).eq('id', id);
  }

  /// -- Curated food catalog search
  /// Matches every typed word against the food name or its search words
  /// (English, Hinglish and Hindi), e.g. "chawal", "दाल", "brown rice".
  Future<List<FoodItemModel>> searchCatalog(String query) async {
    final words = XFoodSearch.words(query);
    if (words.isEmpty) return [];

    // The database narrows the list (each word somewhere in the name or search words) ...
    var request = _supabase
        .from('foods')
        .select('id, name, unit_weights, is_verified, source, search_terms, food_nutrition(*)');
    for (final word in words) {
      request = request.or('name.ilike."%$word%",search_terms.ilike."%$word%"');
    }
    final rows = await request.limit(60);

    // ... and the app keeps only whole-word matches and puts the best ones first.
    return XFoodSearch.filterAndRank(rows, words).take(20).map(FoodItemModel.fromCatalog).toList();
  }

  /// -- Own diary entries for one day
  Future<List<MealEntryModel>> fetchEntries(DateTime date) async {
    final rows = await _supabase
        .from('meal_entries')
        .select()
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .eq('entry_date', XHelperFunctions.toDbDate(date))
        .order('consumed_at');
    return rows.map(MealEntryModel.fromJson).toList();
  }

  /// -- Own diary entries between two days (inclusive)
  Future<List<MealEntryModel>> fetchEntriesBetween(DateTime from, DateTime to) async {
    final rows = await _supabase
        .from('meal_entries')
        .select()
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .gte('entry_date', XHelperFunctions.toDbDate(from))
        .lte('entry_date', XHelperFunctions.toDbDate(to))
        .order('entry_date');
    return rows.map(MealEntryModel.fromJson).toList();
  }

  /// -- Save a confirmed entry. `client_entry_id` makes a retried save a no-op
  /// instead of a duplicate.
  Future<void> addEntry(MealEntryModel entry) async {
    await _supabase
        .from('meal_entries')
        .upsert(entry.toJson(_uid), onConflict: 'owner_id,client_entry_id', ignoreDuplicates: true);
  }

  Future<void> deleteEntry(String id) async {
    await _supabase.from('meal_entries').delete().eq('id', id);
  }

  /// -- Daily nutrition goals
  Future<NutritionGoalModel?> fetchGoals() async {
    final row = await _supabase
        .from('nutrition_goals')
        .select()
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .maybeSingle();
    return row == null ? null : NutritionGoalModel.fromJson(row);
  }

  Future<void> saveGoals(NutritionGoalModel goals) async {
    final existing = await _supabase
        .from('nutrition_goals')
        .select('id')
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .maybeSingle();
    if (existing == null) {
      await _supabase.from('nutrition_goals').insert({'owner_id': _uid, ...goals.toJson()});
    } else {
      await _supabase.from('nutrition_goals').update(goals.toJson()).eq('id', existing['id']);
    }
  }
}
