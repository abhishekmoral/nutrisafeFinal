import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';

class LoginHeader extends StatelessWidget {
  const LoginHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Logo
        Container(
          padding: const EdgeInsets.all(XSizes.md),
          decoration: BoxDecoration(
            color: XColors.primaryBackground,
            borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
          ),
          child: const Icon(Iconsax.health, size: 44, color: XColors.primary),
        ),
        const SizedBox(height: XSizes.lg),

        /// Title & SubTitle
        Text(XTexts.loginTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: XSizes.sm),
        Text(XTexts.loginSubTitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
