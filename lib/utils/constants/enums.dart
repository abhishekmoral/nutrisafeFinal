import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// -- Meal categories of the Food Diary.
enum MealType {
  breakfast('breakfast', 'Breakfast'),
  lunch('lunch', 'Lunch'),
  dinner('dinner', 'Dinner'),
  snack('snack', 'Snacks');

  const MealType(this.value, this._label);
  final String value;
  final String _label;

  /// Shown to the user, in the app language.
  String get label => _label.tr;

  static MealType fromValue(String? value) =>
      MealType.values.firstWhere((e) => e.value == value, orElse: () => MealType.snack);
}

/// -- How trustworthy a nutrition number is. Shown to the user next to values.
enum NutritionQuality {
  verified('verified', 'Verified'),
  calculated('calculated', 'Calculated'),
  estimated('estimated', 'Estimated'),
  userEntered('user_entered', 'Entered by you'),
  unknown('unknown', 'Unknown');

  const NutritionQuality(this.value, this._label);
  final String value;
  final String _label;

  /// Shown to the user, in the app language.
  String get label => _label.tr;

  static NutritionQuality fromValue(String? value) => NutritionQuality.values
      .firstWhere((e) => e.value == value, orElse: () => NutritionQuality.unknown);
}

/// -- What the per-quantity nutrition numbers refer to.
enum NutritionBasis {
  per100g('per_100g', 'per 100 g'),
  per100ml('per_100ml', 'per 100 ml'),
  perServing('per_serving', 'per serving'),
  perPackage('per_package', 'per package');

  const NutritionBasis(this.value, this._label);
  final String value;
  final String _label;

  /// Shown to the user, in the app language.
  String get label => _label.tr;

  static NutritionBasis fromValue(String? value) => NutritionBasis.values
      .firstWhere((e) => e.value == value, orElse: () => NutritionBasis.per100g);
}

/// -- Languages supported by the AI Health Agent.
enum AppLanguage {
  english('en', 'English'),
  hindi('hi', 'हिन्दी'),
  hinglish('hinglish', 'Hinglish'),
  bengali('bn', 'বাংলা'),
  tamil('ta', 'தமிழ்'),
  telugu('te', 'తెలుగు'),
  marathi('mr', 'मराठी'),
  gujarati('gu', 'ગુજરાતી'),
  punjabi('pa', 'ਪੰਜਾਬੀ'),
  urdu('ur', 'اردو'),
  kannada('kn', 'ಕನ್ನಡ'),
  malayalam('ml', 'മലയാളം');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label; // the language's own name, never translated

  /// The app locale for this language. Hinglish has no locale of its own, so it uses English (India).
  Locale get locale => switch (this) {
    AppLanguage.english => const Locale('en', 'US'),
    AppLanguage.hinglish => const Locale('en', 'IN'),
    _ => Locale(code),
  };

  /// Urdu is written right to left.
  bool get isRightToLeft => this == AppLanguage.urdu;

  static AppLanguage fromCode(String? code) =>
      AppLanguage.values.firstWhere((e) => e.code == code, orElse: () => AppLanguage.english);
}
