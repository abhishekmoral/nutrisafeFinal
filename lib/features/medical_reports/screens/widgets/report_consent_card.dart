import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';

/// -- Explains and asks for the separate permission to let the AI read medical reports.
class XReportConsentCard extends StatelessWidget {
  const XReportConsentCard({super.key, required this.allowed, required this.onChanged});

  final bool allowed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return XRoundedContainer(
      showBorder: true,
      borderColor: XColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.shield_tick, color: XColors.primary),
              const SizedBox(width: XSizes.sm),
              Expanded(child: Text(XTexts.reportAiConsentTitle, style: textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: XSizes.sm),
          Text(XTexts.reportAiConsentBody, style: textTheme.bodyMedium),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: allowed,
            onChanged: onChanged,
            title: Text('Allow AI to read my medical reports'.tr),
          ),
          Text(
            'Without this you can still upload reports and type the values in yourself.'.tr,
            style: textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}
