import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../models/chat_message_model.dart';

class XChatBubble extends StatelessWidget {
  const XChatBubble({super.key, required this.message, this.onRetry});

  final ChatMessageModel message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final dark = XHelperFunctions.isDarkMode(context);
    final isUser = message.isUser;
    final flagged = message.safetyLevel != null;

    final Color background;
    if (message.isError) {
      background = XColors.error.withValues(alpha: 0.12);
    } else if (isUser) {
      background = XColors.primary;
    } else {
      background = dark ? XColors.darkContainer : XColors.lightContainer;
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: XSizes.sm),
        padding: const EdgeInsets.symmetric(horizontal: XSizes.md, vertical: XSizes.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
          border: flagged ? Border.all(color: XColors.error, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (flagged) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.warning_2, size: XSizes.iconSm, color: XColors.error),
                  const SizedBox(width: XSizes.xs),
                  Text(
                    message.safetyLevel == 'emergency' ? 'Emergency guidance'.tr : 'Medical attention advised'.tr,
                    style: Theme.of(context).textTheme.labelLarge!.apply(color: XColors.error),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.xs),
            ],
            SelectableText(
              message.content,
              style: Theme.of(context).textTheme.bodyMedium!.apply(color: isUser ? Colors.white : null),
            ),
            if (onRetry != null)
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Iconsax.refresh, size: XSizes.iconSm),
                label: Text('Try again'.tr),
              ),
          ],
        ),
      ),
    );
  }
}

/// -- "The agent is writing" placeholder
class XChatTypingBubble extends StatelessWidget {
  const XChatTypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = XHelperFunctions.isDarkMode(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: XSizes.sm),
        padding: const EdgeInsets.symmetric(horizontal: XSizes.md, vertical: XSizes.sm),
        decoration: BoxDecoration(
          color: dark ? XColors.darkContainer : XColors.lightContainer,
          borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: XSizes.sm),
            Text('Thinking...'.tr, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}
