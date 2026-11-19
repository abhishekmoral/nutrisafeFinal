import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../controllers/chat_controller.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/chat_empty_state.dart';
import 'widgets/chat_input.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  /// Previous conversations
  void _showHistory(BuildContext context, ChatController controller) {
    controller.loadConversations();
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Obx(() {
          if (controller.conversations.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(XSizes.xl),
              child: Text('No previous conversations'.tr),
            );
          }
          return ListView(
            shrinkWrap: true,
            children: [
              for (final conversation in controller.conversations)
                ListTile(
                  leading: const Icon(Iconsax.message_text),
                  title: Text(
                    conversation['title'] as String? ?? 'Conversation'.tr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    XHelperFunctions.dayLabel(
                      DateTime.parse(conversation['updated_at'] as String).toLocal(),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    controller.openConversation(conversation['id'] as String);
                  },
                ),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ChatController controller) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear this conversation?'.tr),
        content: Text('The messages will be permanently deleted.'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Clear'.tr)),
        ],
      ),
    );
    if (clear == true) controller.clearConversation();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ChatController.instance;
    return Scaffold(
      appBar: XAppBar(
        title: Text('AI Health Agent'.tr),
        actions: [
          /// Language selector
          PopupMenuButton<String>(
            tooltip: 'Reply language'.tr,
            icon: const Icon(Iconsax.language_square),
            onSelected: (code) =>
                controller.language.value = code == 'auto' ? null : AppLanguage.fromCode(code),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'auto', child: Text('Auto (my settings)'.tr)),
              for (final language in AppLanguage.values)
                PopupMenuItem(value: language.code, child: Text(language.label)),
            ],
          ),

          /// More
          PopupMenuButton<String>(
            tooltip: 'More'.tr,
            icon: const Icon(Iconsax.more),
            onSelected: (value) {
              if (value == 'new') controller.newConversation();
              if (value == 'history') _showHistory(context, controller);
              if (value == 'clear') _confirmClear(context, controller);
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'new', child: Text('New conversation'.tr)),
              PopupMenuItem(value: 'history', child: Text('Conversation history'.tr)),
              PopupMenuItem(value: 'clear', child: Text('Clear conversation'.tr)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            /// Messages
            Expanded(
              child: Obx(() {
                if (controller.loadingHistory.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (controller.messages.isEmpty) return const XChatEmptyState();
                final showTyping = controller.sending.value;
                return ListView.builder(
                  controller: controller.scrollController,
                  padding: const EdgeInsets.all(XSizes.md),
                  itemCount: controller.messages.length + (showTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == controller.messages.length) return const XChatTypingBubble();
                    final message = controller.messages[index];
                    final isLast = index == controller.messages.length - 1;
                    return XChatBubble(
                      message: message,
                      onRetry: message.isError && isLast && controller.canRetry
                          ? controller.retryLast
                          : null,
                    );
                  },
                );
              }),
            ),

            /// Input
            const XChatInput(),
          ],
        ),
      ),
    );
  }
}
