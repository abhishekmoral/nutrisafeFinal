import 'package:get/get.dart';
/// -- An adult with their own NutriSafe account who joined the family (`family_members`).
class FamilyMemberModel {
  FamilyMemberModel({
    required this.userId,
    required this.role,
    this.fullName,
    this.nutrisafeId,
    required this.joinedAt,
  });

  final String userId;
  final String role; // admin | member
  final String? fullName;
  final String? nutrisafeId;
  final DateTime joinedAt;

  bool get isAdmin => role == 'admin';

  String get displayName {
    final name = (fullName ?? '').trim();
    return name.isEmpty ? 'NutriSafe user'.tr : name;
  }

  String get initial => displayName[0].toUpperCase();

  factory FamilyMemberModel.fromJson(Map<String, dynamic> json) {
    return FamilyMemberModel(
      userId: json['user_id'] as String,
      role: json['role'] as String? ?? 'member',
      fullName: json['full_name'] as String?,
      nutrisafeId: json['nutrisafe_id'] as String?,
      joinedAt: DateTime.parse(json['joined_at'] as String).toLocal(),
    );
  }
}

/// -- What one adult lets another family member see or do with their own data.
class FamilyScope {
  FamilyScope._();

  static const viewProfile = 'view_profile';
  static const viewFoodDiary = 'view_food_diary';
  static const addFood = 'add_food';
  static const editFood = 'edit_food';
  static const deleteFood = 'delete_food';
  static const viewAllergies = 'view_allergies';
  static const viewInsights = 'view_insights';

  /// In display order, with the label and description shown in the app.
  static const all = <(String, String, String)>[
    (viewProfile, 'View profile', 'Age, height, weight and diet'),
    (viewFoodDiary, 'View food diary', 'What you logged and when'),
    (addFood, 'Add food', 'Log food in your diary for you'),
    (editFood, 'Edit food', 'Change the amount of your entries'),
    (deleteFood, 'Delete food', 'Remove entries from your diary'),
    (viewAllergies, 'View allergies', 'Your allergies and intolerances'),
    (viewInsights, 'View insights', 'Daily nutrition totals and goals'),
  ];

  static String label(String scope) =>
      all.firstWhere((s) => s.$1 == scope, orElse: () => (scope, scope, '')).$2.tr;
}
