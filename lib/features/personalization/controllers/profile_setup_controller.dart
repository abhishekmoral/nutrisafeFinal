import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/food/food_repository.dart';
import '../../../data/repositories/user/user_repository.dart';
import '../../../navigation_menu.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/localization/language_helper.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/helpers/nutrition_calculator.dart';
import '../../../utils/popups/loaders.dart';
import '../models/user_model.dart';
import 'user_controller.dart';

/// -- Used for the first-time profile setup and for "Edit profile" later.
class ProfileSetupController extends GetxController {
  static ProfileSetupController get instance => Get.find();

  /// Options
  static const genders = {
    'female': 'Female',
    'male': 'Male',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };
  static const activityLevels = {
    'sedentary': 'Sedentary',
    'light': 'Lightly active',
    'moderate': 'Moderately active',
    'active': 'Very active',
  };
  static const dietaryPreferences = {
    'vegetarian': 'Vegetarian',
    'non_vegetarian': 'Non-vegetarian',
    'vegan': 'Vegan',
    'eggetarian': 'Eggetarian',
    'jain': 'Jain',
    'pescatarian': 'Pescatarian',
    'other': 'Other',
  };
  static const commonAllergens = [
    'Milk',
    'Egg',
    'Peanut',
    'Tree nuts',
    'Wheat / Gluten',
    'Soy',
    'Fish',
    'Shellfish',
    'Sesame',
    'Mustard',
  ];
  static const healthGoals = {
    'healthy_routine': 'Healthy eating routine',
    'dietary_variety': 'More dietary variety',
    'increase_fiber': 'Increase fiber',
    'hydration': 'Better hydration',
    'protein_goal': 'Meet protein goals',
    'track_weight': 'Track weight',
    'monitor_nutrition': 'Monitor nutrition',
    'meal_consistency': 'Meal consistency',
  };

  /// Variables
  final _userRepository = Get.put(UserRepository());
  final _foodRepository = Get.put(FoodRepository());
  GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final location = TextEditingController();
  final intolerances = TextEditingController();
  final customAllergen = TextEditingController();

  final dateOfBirth = Rxn<DateTime>();
  final gender = RxnString();
  final activityLevel = RxnString();
  final dietaryPreference = RxnString();
  final language = AppLanguage.english.obs;
  final selectedAllergens = <String>[].obs;
  final selectedGoals = <String>[].obs;
  final allowAiPersonalization = false.obs;
  final loading = true.obs;
  final saving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final user = UserController.instance.user.value;
      fullName.text = user.fullName ?? '';
      height.text = user.heightCm?.toStringAsFixed(0) ?? '';
      weight.text = user.weightKg?.toString() ?? '';
      location.text = user.location ?? '';
      dateOfBirth.value = user.dateOfBirth;
      gender.value = user.gender;
      activityLevel.value = user.activityLevel;
      dietaryPreference.value = user.dietaryPreference;

      final results = await Future.wait([
        _userRepository.fetchAllergies(),
        _userRepository.fetchIntolerances(),
        _userRepository.fetchHealthGoals(),
        _userRepository.fetchSettings(),
        _userRepository.fetchAiPermissions(),
      ]);
      selectedAllergens.assignAll(results[0] as List<String>);
      intolerances.text = (results[1] as List<String>).join(', ');
      selectedGoals.assignAll(results[2] as List<String>);
      language.value = XLanguageHelper.current; // the account language was applied at sign-in
      allowAiPersonalization.value = (results[4] as Map<String, bool>).values.any((v) => v);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load profile'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  void toggleAllergen(String allergen) {
    selectedAllergens.contains(allergen)
        ? selectedAllergens.remove(allergen)
        : selectedAllergens.add(allergen);
  }

  void addCustomAllergen() {
    final value = customAllergen.text.trim();
    if (value.isEmpty) return;
    if (!selectedAllergens.any((a) => a.toLowerCase() == value.toLowerCase())) {
      selectedAllergens.add(value);
    }
    customAllergen.clear();
  }

  void toggleGoal(String goal) {
    selectedGoals.contains(goal) ? selectedGoals.remove(goal) : selectedGoals.add(goal);
  }

  Future<void> pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth.value ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
    );
    if (picked != null) dateOfBirth.value = picked;
  }

  /// -- Save everything the user filled in.
  Future<void> save({required bool isEditing}) async {
    if (!formKey.currentState!.validate()) return;
    try {
      saving.value = true;
      final current = UserController.instance.user.value;
      final updated = UserModel(
        id: current.id,
        email: current.email,
        nutrisafeId: current.nutrisafeId,
        fullName: fullName.text.trim(),
        dateOfBirth: dateOfBirth.value,
        gender: gender.value,
        heightCm: double.tryParse(height.text.trim()),
        weightKg: double.tryParse(weight.text.trim()),
        activityLevel: activityLevel.value,
        dietaryPreference: dietaryPreference.value,
        location: location.text.trim().isEmpty ? null : location.text.trim(),
        onboardingCompleted: true,
      );
      await UserController.instance.saveUserRecord(updated);

      final intoleranceList = intolerances.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
      await Future.wait([
        _userRepository.saveAllergies(selectedAllergens.toList()),
        _userRepository.saveIntolerances(intoleranceList),
        _userRepository.saveHealthGoals(selectedGoals.toList()),
        _userRepository.updateSettings({'preferred_language': language.value.code}),
        _saveAiConsent(),
      ]);

      // Suggested goals only when the user has not set their own.
      final goals = await _foodRepository.fetchGoals();
      if (goals == null || !goals.isCustom) {
        await _foodRepository.saveGoals(XNutritionCalculator.suggestGoals(updated));
      }

      if (isEditing) {
        Get.back();
        XLoaders.successSnackBar(title: 'Profile updated'.tr);
      } else {
        Get.offAll(() => const NavigationMenu());
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save'.tr, message: XExceptionHandler.message(e));
    } finally {
      saving.value = false;
    }
  }

  /// -- Skip: only mark onboarding as done, everything can be filled in later.
  Future<void> skip() async {
    try {
      saving.value = true;
      final user = UserController.instance.user.value..onboardingCompleted = true;
      await UserController.instance.saveUserRecord(user);
      Get.offAll(() => const NavigationMenu());
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not continue'.tr, message: XExceptionHandler.message(e));
    } finally {
      saving.value = false;
    }
  }

  /// The AI agent may only read what the user explicitly allowed.
  Future<void> _saveAiConsent() async {
    const contextTypes = [
      'profile',
      'body_metrics',
      'dietary_preferences',
      'allergies',
      'food_diary',
      'health_goals',
      'symptoms',
      'progress',
      'ai_history',
    ];
    final allowed = allowAiPersonalization.value;
    await _userRepository.recordConsent('ai_processing', allowed);
    for (final type in contextTypes) {
      await _userRepository.setAiPermission(type, allowed);
    }
  }

  @override
  void onClose() {
    fullName.dispose();
    height.dispose();
    weight.dispose();
    location.dispose();
    intolerances.dispose();
    customAllergen.dispose();
    super.onClose();
  }
}
