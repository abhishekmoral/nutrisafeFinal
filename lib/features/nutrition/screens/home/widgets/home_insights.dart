import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../navigation_menu.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../ai_agent/controllers/chat_controller.dart';
import '../../../controllers/food_diary_controller.dart';
import '../../../controllers/water_controller.dart';
import '../../../../../utils/localization/translations.dart';

/// -- Facts calculated from what the user logged today, compared with their own goals.
/// These are not AI output; AI suggestions are requested separately and labelled as such.
class XHomeInsights extends StatelessWidget {
  const XHomeInsights({super.key});

  List<String> _facts() {
    final diary = FoodDiaryController.instance;
    final water = WaterController.instance;
    final today = DateTime.now();
    final totals = diary.totalsOn(today);
    final goals = diary.goals.value;
    final facts = <String>[];
    String n(double? v) => XHelperFunctions.formatNumber(v ?? 0, decimals: 0);

    if (diary.entriesOn(today).isEmpty) {
      facts.add('You have not logged any food today.'.tr);
    } else if (goals != null) {
      if (goals.proteinG != null && (totals.proteinG ?? 0) < goals.proteinG!) {
        facts.add('Protein so far: {value} g of your {goal} g goal.'.trf({'value': n(totals.proteinG), 'goal': n(goals.proteinG)}));
      }
      if (goals.fiberG != null && (totals.fiberG ?? 0) < goals.fiberG!) {
        facts.add('Fiber so far: {value} g of your {goal} g goal.'.trf({'value': n(totals.fiberG), 'goal': n(goals.fiberG)}));
      }
      if (goals.sodiumMg != null && (totals.sodiumMg ?? 0) > goals.sodiumMg!) {
        facts.add(
          'Sodium logged today ({value} mg) is above your {goal} mg limit.'
              .trf({'value': n(totals.sodiumMg), 'goal': n(goals.sodiumMg)}),
        );
      }
      if (goals.calories != null && (totals.calories ?? 0) > goals.calories!) {
        facts.add(
          'Calories logged today ({value} kcal) are above your {goal} kcal goal.'
              .trf({'value': n(totals.calories), 'goal': n(goals.calories)}),
        );
      }
    }

    final target = water.targetMl;
    if (target != null && water.todayTotal < target) {
      facts.add('Water so far: {value} ml of your {goal} ml target.'.trf({'value': water.todayTotal, 'goal': n(target)}));
    }
    if (facts.isEmpty) facts.add('You are on track with the goals you set for today.'.tr);
    return facts;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final facts = _facts();
      return XRoundedContainer(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From your logged data (calculated)'.tr, style: textTheme.labelMedium),
            const SizedBox(height: XSizes.sm),
            for (final fact in facts)
              Padding(
                padding: const EdgeInsets.only(bottom: XSizes.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Iconsax.chart_2, size: XSizes.iconSm, color: XColors.primary),
                    const SizedBox(width: XSizes.sm),
                    Expanded(child: Text(fact, style: textTheme.bodyMedium)),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  NavigationController.instance.selectedIndex.value = 2;
                  ChatController.instance.sendMessage('Analyze my daily nutrition.'.tr);
                },
                icon: const Icon(Iconsax.magic_star),
                label: Text('Ask the AI agent for suggestions'.tr),
              ),
            ),
          ],
        ),
      );
    });
  }
}
