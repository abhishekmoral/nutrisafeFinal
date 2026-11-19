import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/validators/validation.dart';
import '../../../personalization/controllers/profile_setup_controller.dart';
import '../../controllers/managed_profile_form_controller.dart';
import '../../models/managed_profile_model.dart';

/// -- Method 02: create a managed profile (no account, no login), or edit one.
class ManagedProfileFormScreen extends StatelessWidget {
  const ManagedProfileFormScreen({super.key, this.existing, this.existingAllergies = const []});

  final ManagedProfileModel? existing;
  final List<String> existingAllergies;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      ManagedProfileFormController(existing: existing, existingAllergies: existingAllergies),
      tag: existing?.id ?? 'new',
    );
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: XAppBar(
        showBackArrow: true,
        title: Text(controller.isEditing ? 'Edit Member Profile'.tr : 'Create Member Profile'.tr),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        child: Form(
          key: controller.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!controller.isEditing)
                Text(
                  'For a child, an elder or anyone without their own NutriSafe account or phone. No login is created; you manage the profile as its guardian.'.tr,
                  style: textTheme.labelMedium,
                ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Personal information
              XSectionHeading(title: 'Personal Information'.tr, showActionButton: false),
              const SizedBox(height: XSizes.spaceBtwItems),
              TextFormField(
                controller: controller.fullName,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                validator: (v) => XValidator.validateEmptyText('Full name'.tr, v),
                decoration: InputDecoration(
                  labelText: 'Full Name *'.tr,
                  prefixIcon: Icon(Iconsax.user),
                  counterText: '',
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Obx(
                () => InkWell(
                  onTap: () => controller.pickDateOfBirth(context),
                  borderRadius: BorderRadius.circular(XSizes.inputFieldRadius),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date of Birth *'.tr,
                      prefixIcon: const Icon(Iconsax.calendar_1),
                      errorText: controller.dobError.value,
                    ),
                    child: Text(
                      controller.dateOfBirth.value == null
                          ? 'Select'.tr
                          : XHelperFunctions.getFormattedDate(controller.dateOfBirth.value!),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Obx(
                () => DropdownButtonFormField<String>(
                  initialValue: controller.gender.value,
                  decoration: InputDecoration(labelText: 'Gender (Optional)'.tr, prefixIcon: Icon(Iconsax.profile_2user)),
                  items: ProfileSetupController.genders.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                      .toList(),
                  onChanged: (v) => controller.gender.value = v,
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Obx(
                () => DropdownButtonFormField<String>(
                  initialValue: controller.relationship.value,
                  decoration: InputDecoration(labelText: 'Relationship (Optional)'.tr, prefixIcon: Icon(Iconsax.people)),
                  items: managedRelationships.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                      .toList(),
                  onChanged: (v) => controller.relationship.value = v,
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Dietary preferences
              XSectionHeading(title: 'Dietary Preferences'.tr, showActionButton: false),
              const SizedBox(height: XSizes.spaceBtwItems),
              Obx(
                () => DropdownButtonFormField<String>(
                  initialValue: controller.dietaryPreference.value,
                  decoration: InputDecoration(labelText: 'Food Preference'.tr, prefixIcon: Icon(Iconsax.reserve)),
                  items: ProfileSetupController.dietaryPreferences.entries
                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                      .toList(),
                  onChanged: (v) => controller.dietaryPreference.value = v,
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Food allergies
              XSectionHeading(title: 'Food Allergies'.tr, showActionButton: false),
              Text('Select applicable allergies.'.tr, style: textTheme.labelMedium),
              const SizedBox(height: XSizes.sm),
              Obx(
                () => Wrap(
                  spacing: XSizes.sm,
                  runSpacing: XSizes.xs,
                  children: [
                    for (final allergy in ManagedProfileFormController.allergyOptions)
                      FilterChip(
                        label: Text(allergy.tr),
                        selected: controller.selectedAllergies.contains(allergy),
                        labelStyle: TextStyle(
                          color: controller.selectedAllergies.contains(allergy) ? Colors.white : null,
                        ),
                        onSelected: (_) => controller.toggleAllergy(allergy),
                      ),
                    FilterChip(
                      label: Text('Other'.tr),
                      selected: controller.otherSelected.value,
                      labelStyle: TextStyle(color: controller.otherSelected.value ? Colors.white : null),
                      onSelected: (v) => controller.otherSelected.value = v,
                    ),
                  ],
                ),
              ),
              Obx(
                () => controller.otherSelected.value
                    ? Padding(
                        padding: const EdgeInsets.only(top: XSizes.sm),
                        child: TextFormField(
                          controller: controller.otherAllergies,
                          maxLength: 300,
                          decoration: InputDecoration(
                            labelText: 'Other allergies'.tr,
                            helperText: 'Separate with commas, e.g. Sesame, Mustard'.tr,
                            counterText: '',
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),

              /// -- Notes
              TextFormField(
                controller: controller.notes,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Additional Notes (Optional)'.tr),
              ),
              const SizedBox(height: XSizes.sm),
              Row(
                children: [
                  const Icon(Iconsax.info_circle, size: XSizes.iconSm, color: XColors.darkGrey),
                  const SizedBox(width: XSizes.xs),
                  Expanded(
                    child: Text(
                      'Allergy checks in the app use this list, but cannot guarantee a food is safe.'.tr,
                      style: textTheme.labelMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.saving.value ? null : controller.save,
                    child: Text(
                      controller.saving.value
                          ? 'Saving...'.tr
                          : (controller.isEditing ? 'Save Changes'.tr : 'Create Member Profile'.tr),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
