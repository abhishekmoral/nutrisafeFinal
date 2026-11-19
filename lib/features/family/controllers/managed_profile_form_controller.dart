import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/family/family_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/managed_profile_model.dart';
import 'family_controller.dart';

/// -- Create a managed profile ("Add manually") or edit one.
class ManagedProfileFormController extends GetxController {
  ManagedProfileFormController({this.existing, this.existingAllergies = const []});

  static ManagedProfileFormController get instance => Get.find();

  /// Allergy choices shown as chips (PRD list). "Other" opens a text field.
  static const allergyOptions = ['Milk', 'Peanuts', 'Tree Nuts', 'Soy', 'Eggs', 'Gluten', 'Seafood'];

  final ManagedProfileModel? existing; // null = create
  final List<String> existingAllergies;

  /// Variables
  final _repository = Get.put(FamilyRepository());
  final formKey = GlobalKey<FormState>();
  final fullName = TextEditingController();
  final otherAllergies = TextEditingController();
  final notes = TextEditingController();
  final dateOfBirth = Rxn<DateTime>();
  final dobError = RxnString();
  final gender = RxnString();
  final relationship = RxnString();
  final dietaryPreference = RxnString();
  final selectedAllergies = <String>[].obs;
  final otherSelected = false.obs;
  final saving = false.obs;

  bool get isEditing => existing != null;

  @override
  void onInit() {
    super.onInit();
    final p = existing;
    if (p != null) {
      fullName.text = p.fullName;
      notes.text = p.notes ?? '';
      dateOfBirth.value = p.dateOfBirth;
      gender.value = p.gender;
      relationship.value = p.relationship;
      dietaryPreference.value = p.dietaryPreference;
      selectedAllergies.assignAll(existingAllergies.where(allergyOptions.contains));
      final others = existingAllergies.where((a) => !allergyOptions.contains(a)).toList();
      if (others.isNotEmpty) {
        otherSelected.value = true;
        otherAllergies.text = others.join(', ');
      }
    }
  }

  void toggleAllergy(String allergy) {
    selectedAllergies.contains(allergy) ? selectedAllergies.remove(allergy) : selectedAllergies.add(allergy);
  }

  Future<void> pickDateOfBirth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth.value ?? DateTime(now.year - 8),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Date of birth'.tr,
    );
    if (picked != null) {
      dateOfBirth.value = picked;
      dobError.value = null;
    }
  }

  List<String> get _allAllergies {
    final others = otherSelected.value
        ? otherAllergies.text.split(',').map((a) => a.trim()).where((a) => a.isNotEmpty)
        : const <String>[];
    return {...selectedAllergies, ...others}.toList();
  }

  Future<void> save() async {
    final formOk = formKey.currentState!.validate();
    dobError.value = dateOfBirth.value == null ? 'Date of birth is required.'.tr : null;
    if (!formOk || dateOfBirth.value == null || saving.value) return;

    final note = notes.text.trim();
    try {
      saving.value = true;
      final p = existing;
      if (p == null) {
        await _repository.createManagedProfile(
          fullName: fullName.text.trim(),
          dateOfBirth: dateOfBirth.value!,
          gender: gender.value,
          relationship: relationship.value,
          dietaryPreference: dietaryPreference.value,
          allergies: _allAllergies,
          notes: note.isEmpty ? null : note,
        );
      } else {
        await _repository.updateManagedProfile(
          id: p.id,
          fullName: fullName.text.trim(),
          dateOfBirth: dateOfBirth.value!,
          gender: gender.value,
          relationship: relationship.value,
          dietaryPreference: dietaryPreference.value,
          notes: note.isEmpty ? null : note,
        );
        await _repository.saveManagedAllergies(p.id, _allAllergies);
      }
      if (Get.isRegistered<FamilyController>()) FamilyController.instance.load();
      Get.back(result: true);
      XLoaders.successSnackBar(
        title: p == null ? 'Member profile created'.tr : 'Profile updated'.tr,
        message: fullName.text.trim(),
      );
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save the profile'.tr, message: XExceptionHandler.message(e));
    } finally {
      saving.value = false;
    }
  }

  @override
  void onClose() {
    fullName.dispose();
    otherAllergies.dispose();
    notes.dispose();
    super.onClose();
  }
}
