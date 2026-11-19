import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../navigation_menu.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/enums.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../ai_agent/controllers/chat_controller.dart';
import '../../add_food/add_food.dart';
import '../../../../medical_reports/screens/reports/reports.dart';

class XHomeQuickActions extends StatelessWidget {
  const XHomeQuickActions({super.key});

  /// Which meal should the food go to?
  Future<void> _addFood(BuildContext context, {bool scan = false}) async {
    final meal = await showModalBottomSheet<MealType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final meal in MealType.values)
              ListTile(
                title: Text(meal.label),
                trailing: const Icon(Iconsax.arrow_right_3),
                onTap: () => Navigator.pop(context, meal),
              ),
          ],
        ),
      ),
    );
    if (meal == null) return;
    Get.to(() => AddFoodScreen(mealType: meal, date: DateTime.now(), startWithScan: scan));
  }

  /// Open the AI tab, optionally starting with a prompt.
  void _openChat([String? prompt]) {
    NavigationController.instance.selectedIndex.value = 2;
    if (prompt != null) ChatController.instance.sendMessage(prompt);
  }

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      (Iconsax.add_square, 'Add Food'.tr, () => _addFood(context)),
      (Iconsax.scan_barcode, 'Scan Product'.tr, () => _addFood(context, scan: true)),
      (Iconsax.message_text, 'Chat with AI'.tr, () => _openChat()),
      // Water has its own card with a quick-add button just above, so this slot opens reports.
      (Iconsax.document_upload, 'Upload Report'.tr, () => Get.to(() => const MedicalReportsScreen())),
      (Iconsax.calendar_tick, 'Meal Plan'.tr, () => _openChat('Create a meal plan for me for today.'.tr)),
      (Iconsax.health, 'Add Symptoms'.tr, () => _openChat('I want to tell you about a symptom.'.tr)),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: XSizes.gridViewSpacing,
      crossAxisSpacing: XSizes.gridViewSpacing,
      childAspectRatio: 1.15,
      children: [
        for (final (icon, label, onTap) in actions)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
            child: XRoundedContainer(
              padding: const EdgeInsets.all(XSizes.sm),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: XColors.primary, size: XSizes.iconLg),
                  const SizedBox(height: XSizes.sm),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelLarge,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
