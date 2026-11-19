import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/sizes.dart';
import '../../../controllers/chat_controller.dart';

class XChatInput extends StatelessWidget {
  const XChatInput({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ChatController.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(XSizes.md, XSizes.xs, XSizes.md, XSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          /// Text input
          Expanded(
            child: TextField(
              controller: controller.input,
              minLines: 1,
              maxLines: 5,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your question...'.tr,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(horizontal: XSizes.md, vertical: XSizes.md),
              ),
            ),
          ),
          const SizedBox(width: XSizes.sm),

          /// Send button
          Obx(
            () => IconButton.filled(
              tooltip: 'Send'.tr,
              onPressed: controller.sending.value ? null : () => controller.sendMessage(),
              icon: const Icon(Iconsax.send_1),
            ),
          ),
        ],
      ),
    );
  }
}
