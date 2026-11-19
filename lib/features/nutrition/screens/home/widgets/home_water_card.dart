import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../controllers/water_controller.dart';
import '../../water/water_tracker.dart';
import '../../../../../utils/localization/translations.dart';

class XHomeWaterCard extends StatelessWidget {
  const XHomeWaterCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = WaterController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final target = controller.targetMl;
      return InkWell(
        onTap: () => Get.to(() => const WaterTrackerScreen()),
        borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
        child: XRoundedContainer(
          backgroundColor: XColors.water.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(Iconsax.drop, color: XColors.water, size: XSizes.iconLg),
              const SizedBox(width: XSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water'.tr, style: textTheme.labelLarge),
                    Text(
                      target == null
                          ? '${controller.todayTotal} ml'
                          : '${controller.todayTotal} / ${target.toStringAsFixed(0)} ml',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: controller.progress,
                        minHeight: 8,
                        color: XColors.water,
                        backgroundColor: XColors.water.withValues(alpha: 0.2),
                      ),
                    ),
                    const SizedBox(height: XSizes.sm),
                    Wrap(
                      spacing: XSizes.xs,
                      runSpacing: XSizes.xs,
                      children: [
                        for (final ml in const [150, 250, 500])
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                            label: Text('+$ml ml'),
                            tooltip: 'Add {value} ml of water'.trf({'value': ml}),
                            onPressed: () => controller.addWater(ml),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
