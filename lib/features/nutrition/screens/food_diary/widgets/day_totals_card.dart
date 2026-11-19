import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../common/widgets/progress/nutrient_progress.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../controllers/food_diary_controller.dart';
import '../../../../../utils/localization/translations.dart';

/// -- Calculated totals of one day against the user's configured goals.
class XDayTotalsCard extends StatelessWidget {
  const XDayTotalsCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final controller = FoodDiaryController.instance;
    return Obx(() {
      final totals = controller.totalsOn(date);
      final goals = controller.goals.value;
      final unknown = controller.unknownCaloriesCount(date);
      return XRoundedContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            XNutrientProgress(
              label: 'Calories'.tr,
              value: totals.calories,
              goal: goals?.calories,
              unit: 'kcal',
              color: XColors.calories,
            ),
            const SizedBox(height: XSizes.spaceBtwItems),
            Row(
              children: [
                Expanded(
                  child: XNutrientProgress(
                    label: 'Protein'.tr,
                    value: totals.proteinG,
                    goal: goals?.proteinG,
                    unit: 'g',
                    color: XColors.protein,
                  ),
                ),
                const SizedBox(width: XSizes.md),
                Expanded(
                  child: XNutrientProgress(
                    label: 'Carbs'.tr,
                    value: totals.carbsG,
                    goal: goals?.carbsG,
                    unit: 'g',
                    color: XColors.carbs,
                  ),
                ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwItems),
            Row(
              children: [
                Expanded(
                  child: XNutrientProgress(
                    label: 'Fat'.tr,
                    value: totals.fatG,
                    goal: goals?.fatG,
                    unit: 'g',
                    color: XColors.fat,
                  ),
                ),
                const SizedBox(width: XSizes.md),
                Expanded(
                  child: XNutrientProgress(
                    label: 'Fiber'.tr,
                    value: totals.fiberG,
                    goal: goals?.fiberG,
                    unit: 'g',
                    color: XColors.fiber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwItems),
            Row(
              children: [
                Expanded(child: _Limit(label: 'Sugar'.tr, value: totals.sugarG, limit: goals?.sugarG, unit: 'g')),
                const SizedBox(width: XSizes.md),
                Expanded(child: _Limit(label: 'Sodium'.tr, value: totals.sodiumMg, limit: goals?.sodiumMg, unit: 'mg')),
              ],
            ),
            if (unknown > 0) ...[
              const SizedBox(height: XSizes.spaceBtwItems),
              Text(
                unknown == 1
                    ? '1 item without nutrition data is not included in these totals.'.tr
                    : '{count} items without nutrition data are not included in these totals.'.trf({'count': unknown}),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// Sugar / sodium against a daily limit: red when above it.
class _Limit extends StatelessWidget {
  const _Limit({required this.label, required this.value, required this.limit, required this.unit});

  final String label;
  final double? value;
  final double? limit;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final over = limit != null && (value ?? 0) > limit!;
    return XNutrientProgress(
      label: over ? '$label · ${'above limit'.tr}' : label,
      value: value,
      goal: limit,
      unit: unit,
      color: over ? XColors.error : XColors.secondary,
    );
  }
}
