import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/localization/language_helper.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/validators/validation.dart';
import '../../controllers/profile_setup_controller.dart';
import 'widgets/choice_chips.dart';

class ProfileSetupScreen extends StatelessWidget {
  const ProfileSetupScreen({super.key, this.isEditing = false});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfileSetupController());
    return Scaffold(
      appBar: XAppBar(
        showBackArrow: isEditing,
        title: Text(isEditing ? 'Edit profile'.tr : 'Set up your profile'.tr),
        actions: [
          if (!isEditing) TextButton(onPressed: controller.skip, child: Text(XTexts.xSkip)),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) return const Center(child: CircularProgressIndicator());
        return SingleChildScrollView(
          padding: const EdgeInsets.all(XSizes.defaultSpace),
          child: Form(
            key: controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isEditing) ...[
                  Text(
                    'Only your name is needed. Everything else is optional and can be changed later.'.tr,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: XSizes.spaceBtwItems),
                ],

                /// -- About you
                XSectionHeading(title: 'About you'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                TextFormField(
                  controller: controller.fullName,
                  validator: (value) => XValidator.validateEmptyText('Full name'.tr, value),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: XTexts.xFullName,
                    prefixIcon: Icon(Iconsax.user),
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwInputFields),

                /// Date of birth
                Obx(
                  () => InkWell(
                    onTap: () => controller.pickDateOfBirth(context),
                    borderRadius: BorderRadius.circular(XSizes.inputFieldRadius),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Date of birth'.tr,
                        prefixIcon: Icon(Iconsax.calendar_1),
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

                /// Gender
                Obx(
                  () => DropdownButtonFormField<String>(
                    initialValue: controller.gender.value,
                    decoration: InputDecoration(
                      labelText: 'Gender (optional)'.tr,
                      prefixIcon: Icon(Iconsax.profile_2user),
                    ),
                    items: ProfileSetupController.genders.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                        .toList(),
                    onChanged: (value) => controller.gender.value = value,
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwInputFields),

                /// Height & Weight
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: controller.height,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => XValidator.validateOptionalRange('Height'.tr, v, 30, 272),
                        decoration: InputDecoration(labelText: 'Height (cm)'.tr),
                      ),
                    ),
                    const SizedBox(width: XSizes.spaceBtwInputFields),
                    Expanded(
                      child: TextFormField(
                        controller: controller.weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => XValidator.validateOptionalRange('Weight'.tr, v, 1, 500),
                        decoration: InputDecoration(labelText: 'Weight (kg)'.tr),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: XSizes.spaceBtwInputFields),

                /// Activity level
                Obx(
                  () => DropdownButtonFormField<String>(
                    initialValue: controller.activityLevel.value,
                    decoration: InputDecoration(
                      labelText: 'Activity level'.tr,
                      prefixIcon: Icon(Iconsax.activity),
                    ),
                    items: ProfileSetupController.activityLevels.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                        .toList(),
                    onChanged: (value) => controller.activityLevel.value = value,
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwInputFields),

                /// Location
                TextFormField(
                  controller: controller.location,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'City / State (optional)'.tr,
                    helperText: 'Used only for regional food suggestions'.tr,
                    prefixIcon: Icon(Iconsax.location),
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// -- Food
                XSectionHeading(title: 'Food preferences'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                Obx(
                  () => DropdownButtonFormField<String>(
                    initialValue: controller.dietaryPreference.value,
                    decoration: InputDecoration(
                      labelText: 'Dietary preference'.tr,
                      prefixIcon: Icon(Iconsax.reserve),
                    ),
                    items: ProfileSetupController.dietaryPreferences.entries
                        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value.tr)))
                        .toList(),
                    onChanged: (value) => controller.dietaryPreference.value = value,
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwItems),

                /// Allergies
                Text('Food allergies'.tr, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: XSizes.sm),
                Obx(
                  () => XChoiceChips(
                    options: {
                      for (final a in {
                        ...ProfileSetupController.commonAllergens,
                        ...controller.selectedAllergens,
                      })
                        a: a,
                    },
                    selected: controller.selectedAllergens.toList(),
                    onToggle: controller.toggleAllergen,
                  ),
                ),
                const SizedBox(height: XSizes.sm),
                TextFormField(
                  controller: controller.customAllergen,
                  onFieldSubmitted: (_) => controller.addCustomAllergen(),
                  decoration: InputDecoration(
                    labelText: 'Add another allergy'.tr,
                    suffixIcon: IconButton(
                      tooltip: 'Add allergy'.tr,
                      onPressed: controller.addCustomAllergen,
                      icon: const Icon(Iconsax.add),
                    ),
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwInputFields),

                /// Intolerances
                TextFormField(
                  controller: controller.intolerances,
                  decoration: InputDecoration(
                    labelText: 'Food intolerances'.tr,
                    helperText: 'Separate with commas, e.g. Lactose, Spicy food'.tr,
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// -- Goals
                XSectionHeading(title: 'Wellness goals'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                Obx(
                  () => XChoiceChips(
                    options: ProfileSetupController.healthGoals,
                    selected: controller.selectedGoals.toList(),
                    onToggle: controller.toggleGoal,
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// -- AI
                XSectionHeading(title: 'AI Health Agent'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                Obx(
                  () => DropdownButtonFormField<AppLanguage>(
                    initialValue: controller.language.value,
                    decoration: InputDecoration(
                      labelText: 'App language'.tr,
                      helperText: 'Used for every screen and for AI replies'.tr,
                      prefixIcon: Icon(Iconsax.language_square),
                    ),
                    items: AppLanguage.values
                        .map((l) => DropdownMenuItem(value: l, child: Text(l.label)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      controller.language.value = value;
                      XLanguageHelper.apply(value); // switch the screens now; saved to the account on Save
                    },
                  ),
                ),
                const SizedBox(height: XSizes.sm),
                Obx(
                  () => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: controller.allowAiPersonalization.value,
                    onChanged: (value) => controller.allowAiPersonalization.value = value,
                    title: Text('Let the AI agent use my data'.tr),
                    subtitle: Text(
                      'Profile, allergies, food diary, symptoms and goals are used to personalise answers. Medical reports need a separate permission. You can turn this off any time in Settings.'.tr,
                    ),
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwItems),
                Text(XTexts.medicalDisclaimer, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// -- Save Button
                SizedBox(
                  width: double.infinity,
                  child: Obx(
                    () => ElevatedButton(
                      onPressed: controller.saving.value
                          ? null
                          : () => controller.save(isEditing: isEditing),
                      child: Text(
                        controller.saving.value
                            ? 'Saving...'.tr
                            : (isEditing ? XTexts.xSave : XTexts.xContinue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
