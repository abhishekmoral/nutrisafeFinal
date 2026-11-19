import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../styles/spacing_styles.dart';

class XSuccessScreen extends StatelessWidget {
  const XSuccessScreen({
    super.key,
    this.icon = Iconsax.tick_circle,
    required this.title,
    required this.subTitle,
    required this.buttonText,
    required this.onPressed,
  });

  final IconData icon;
  final String title, subTitle, buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: XSpacingStyle.paddingWithAppBarHeight * 2,
          child: Column(
            children: [
              /// Icon
              Icon(icon, size: 120, color: XColors.primary),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Title & SubTitle
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              Text(
                subTitle,
                style: Theme.of(context).textTheme.labelLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: onPressed, child: Text(buttonText)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
