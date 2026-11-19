import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../nutrition/models/nutrition_values.dart';

/// -- Today's totals for a family member (calculated from their logged food).
class XNutritionTodayCard extends StatelessWidget {
  const XNutritionTodayCard({super.key, required this.values, this.footer});

  final NutritionValues values;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final items = [
      ('Calories'.tr, values.calories, 'kcal'),
      ('Protein'.tr, values.proteinG, 'g'),
      ('Carbs'.tr, values.carbsG, 'g'),
      ('Fat'.tr, values.fatG, 'g'),
      ('Fiber'.tr, values.fiberG, 'g'),
    ];
    return XRoundedContainer(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today (calculated from logged food)'.tr, style: textTheme.titleMedium),
          const SizedBox(height: XSizes.sm),
          if (values.isEmpty)
            Text('Nothing logged today.'.tr, style: textTheme.bodyMedium)
          else
            Wrap(
              spacing: XSizes.lg,
              runSpacing: XSizes.sm,
              children: [
                for (final (label, value, unit) in items)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: textTheme.labelMedium),
                      Text(
                        value == null ? '–' : '${XHelperFunctions.formatNumber(value, decimals: 0)} $unit',
                        style: textTheme.titleLarge,
                      ),
                    ],
                  ),
              ],
            ),
          if (footer != null) ...[
            const SizedBox(height: XSizes.sm),
            Text(footer!, style: textTheme.labelMedium),
          ],
        ],
      ),
    );
  }
}
