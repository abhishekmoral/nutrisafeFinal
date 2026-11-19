import '../../../utils/constants/enums.dart';
import '../../../utils/helpers/helper_function.dart';
import 'nutrition_values.dart';

/// -- One confirmed food consumption record (`meal_entries` table).
class MealEntryModel {
  MealEntryModel({
    this.id,
    required this.entryDate,
    required this.mealType,
    this.foodId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.consumedAt,
    this.nutrition = NutritionValues.empty,
    this.entrySource = 'manual',
    this.quality = NutritionQuality.unknown,
    this.clientEntryId,
  });

  final String? id;
  final DateTime entryDate;
  final MealType mealType;
  final String? foodId;
  final String foodName;
  final double quantity;
  final String unit;
  final DateTime consumedAt;
  final NutritionValues nutrition;
  final String entrySource;
  final NutritionQuality quality;
  final String? clientEntryId;

  String get quantityLabel => '${XHelperFunctions.formatNumber(quantity)} $unit';

  factory MealEntryModel.fromJson(Map<String, dynamic> json) {
    return MealEntryModel(
      id: json['id'] as String?,
      entryDate: DateTime.parse(json['entry_date'] as String),
      mealType: MealType.fromValue(json['meal_type'] as String?),
      foodId: json['food_id'] as String?,
      foodName: json['food_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String,
      consumedAt: DateTime.parse(json['consumed_at'] as String).toLocal(),
      nutrition: NutritionValues.fromJson(json),
      entrySource: json['entry_source'] as String? ?? 'manual',
      quality: NutritionQuality.fromValue(json['nutrition_quality'] as String?),
      clientEntryId: json['client_entry_id'] as String?,
    );
  }

  Map<String, dynamic> toJson(String ownerId) {
    return {
      'owner_id': ownerId,
      'entry_date': XHelperFunctions.toDbDate(entryDate),
      'meal_type': mealType.value,
      'food_id': foodId,
      'food_name': foodName,
      'quantity': quantity,
      'unit': unit,
      'consumed_at': consumedAt.toUtc().toIso8601String(),
      ...nutrition.toJson(),
      'entry_source': entrySource,
      'nutrition_quality': quality.value,
      'client_entry_id': clientEntryId,
    };
  }
}
