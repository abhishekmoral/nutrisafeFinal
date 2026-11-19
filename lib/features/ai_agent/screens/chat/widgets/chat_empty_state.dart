import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../controllers/chat_controller.dart';

/// -- Shown before the first message: what the agent is, suggested prompts, disclaimer.
class XChatEmptyState extends StatelessWidget {
  const XChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChatController.instance;
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(XSizes.defaultSpace),
      children: [
        const SizedBox(height: XSizes.lg),
        const Icon(Iconsax.magic_star, size: 56, color: XColors.primary),
        const SizedBox(height: XSizes.spaceBtwItems),
        Text('How can I help today?'.tr, style: textTheme.headlineMedium, textAlign: TextAlign.center),
        const SizedBox(height: XSizes.sm),
        Text(
          'Ask in English, Hindi, Hinglish or your own language.'.tr,
          style: textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: XSizes.spaceBtwSections),

        /// Suggested prompts
        for (final prompt in ChatController.suggestedPrompts)
          Padding(
            padding: const EdgeInsets.only(bottom: XSizes.sm),
            child: OutlinedButton(
              onPressed: () => controller.sendMessage(prompt.tr),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: XSizes.md, vertical: XSizes.md),
                textStyle: textTheme.bodyLarge,
              ),
              child: Text(prompt.tr),
            ),
          ),
        const SizedBox(height: XSizes.spaceBtwItems),

        /// Disclaimer
        Text(XTexts.medicalDisclaimer, style: textTheme.labelMedium, textAlign: TextAlign.center),
      ],
    );
  }
}
