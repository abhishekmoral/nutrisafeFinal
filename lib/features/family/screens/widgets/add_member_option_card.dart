import 'package:flutter/material.dart';

import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';

/// -- One of the two ways to add a family member.
class XAddMemberOptionCard extends StatelessWidget {
  const XAddMemberOptionCard({
    super.key,
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
    required this.note,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
  final String note;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return XRoundedContainer(
      showBorder: true,
      padding: const EdgeInsets.all(XSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(XSizes.sm),
                decoration: BoxDecoration(
                  color: XColors.primaryBackground,
                  borderRadius: BorderRadius.circular(XSizes.cardRadiusSm),
                ),
                child: Icon(icon, color: XColors.primary),
              ),
              const SizedBox(width: XSizes.md),
              Text(number, style: textTheme.labelLarge!.apply(color: XColors.primary)),
            ],
          ),
          const SizedBox(height: XSizes.spaceBtwItems),
          Text(title, style: textTheme.headlineSmall),
          const SizedBox(height: XSizes.xs),
          Text(description, style: textTheme.bodyMedium),
          const SizedBox(height: XSizes.xs),
          Text(note, style: textTheme.labelMedium),
          const SizedBox(height: XSizes.md),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: onPressed, child: Text(buttonLabel))),
        ],
      ),
    );
  }
}
