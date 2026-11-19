import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/language/language_picker.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/exceptions/exception_handler.dart';
import '../../../../utils/localization/language_helper.dart';
import '../../../../utils/popups/loaders.dart';
import '../../controllers/user_controller.dart';
import '../../../medical_reports/screens/reports/reports.dart';
import '../../../family/bindings/family_binding.dart';
import '../../../family/screens/family/family.dart';
import '../profile_setup/profile_setup.dart';
import '../settings/ai_privacy_settings.dart';
import '../settings/nutrition_goals.dart';
import 'widgets/settings_menu_tile.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout() async {
    try {
      await AuthenticationRepository.instance.logout();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not log out'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// Account deletion needs the user to type DELETE first.
  Future<void> _deleteAccount(BuildContext context) async {
    final field = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete account?'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your profile, food diary, medical reports, AI conversations and child profiles will be permanently deleted. This cannot be undone.'.tr,
            ),
            const SizedBox(height: XSizes.spaceBtwItems),
            TextField(
              controller: field,
              decoration: InputDecoration(labelText: 'Type DELETE to confirm'.tr),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () => Navigator.pop(context, field.text.trim() == 'DELETE'),
            child: Text('Delete'.tr, style: TextStyle(color: XColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      XLoaders.openLoadingDialog();
      await AuthenticationRepository.instance.deleteAccount();
      XLoaders.stopLoading();
    } catch (e) {
      XLoaders.stopLoading();
      XLoaders.errorSnackBar(title: 'Could not delete account'.tr, message: XExceptionHandler.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = UserController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(title: Text('Profile'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        children: [
          /// User card
          Obx(() {
            final user = controller.user.value;
            return XRoundedContainer(
              backgroundColor: XColors.primary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Text(
                      user.firstName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        color: XColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: XSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (user.fullName ?? '').isEmpty ? 'Your profile'.tr : user.fullName!,
                          style: textTheme.headlineSmall!.apply(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.email,
                          style: textTheme.bodyMedium!.apply(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit profile'.tr,
                    onPressed: () => Get.to(() => const ProfileSetupScreen(isEditing: true)),
                    icon: const Icon(Iconsax.edit, color: Colors.white),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: XSizes.spaceBtwItems),

          /// NutriSafe ID (others use it to add you to their family)
          Obx(() {
            final id = controller.user.value.nutrisafeId;
            if (id == null) return const SizedBox.shrink();
            return XRoundedContainer(
              showBorder: true,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR NUTRISAFE ID'.tr, style: textTheme.labelLarge),
                        Text(id, style: textTheme.headlineMedium),
                        Text(
                          'Share it with a family admin so they can add you.'.tr,
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Copy NutriSafe ID'.tr,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: id));
                      XLoaders.successSnackBar(title: 'NutriSafe ID copied'.tr);
                    },
                    icon: const Icon(Iconsax.copy),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: XSizes.spaceBtwSections),

          /// Account settings
          XSectionHeading(title: 'Account'.tr, showActionButton: false),
          XSettingsMenuTile(
            icon: Iconsax.user_edit,
            title: 'Personal details'.tr,
            subTitle: 'Height, weight, diet, allergies, wellness goals'.tr,
            onTap: () => Get.to(() => const ProfileSetupScreen(isEditing: true)),
          ),
          XSettingsMenuTile(
            icon: Iconsax.people,
            title: 'Family'.tr,
            subTitle: 'Members, managed profiles, invitations and sharing'.tr,
            onTap: () => Get.to(() => const FamilyScreen(), binding: FamilyBinding()),
          ),
          XSettingsMenuTile(
            icon: Iconsax.document_text,
            title: 'Medical reports'.tr,
            subTitle: 'Upload lab reports and see their values explained'.tr,
            onTap: () => Get.to(() => const MedicalReportsScreen()),
          ),
          XSettingsMenuTile(
            icon: Iconsax.chart_success,
            title: 'Daily nutrition goals'.tr,
            subTitle: 'Calories, protein, fiber, water and more'.tr,
            onTap: () => Get.to(() => const NutritionGoalsScreen()),
          ),
          XSettingsMenuTile(
            icon: Iconsax.language_square,
            title: 'Language'.tr,
            subTitle: XLanguageHelper.current.label,
            onTap: () => XLanguagePicker.show(context, saveToAccount: true),
          ),
          XSettingsMenuTile(
            icon: Iconsax.security_user,
            title: 'AI & privacy'.tr,
            subTitle: 'Language and what the AI agent may use'.tr,
            onTap: () => Get.to(() => const AiPrivacySettingsScreen()),
          ),
          const SizedBox(height: XSizes.spaceBtwSections),

          /// Logout & delete
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: _logout, child: Text('Logout'.tr)),
          ),
          const SizedBox(height: XSizes.sm),
          Center(
            child: TextButton(
              onPressed: () => _deleteAccount(context),
              child: Text('Delete account'.tr, style: TextStyle(color: XColors.error)),
            ),
          ),
          const SizedBox(height: XSizes.spaceBtwItems),
          Text(XTexts.medicalDisclaimer, style: textTheme.labelMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
