import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/ai/ai_repository.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/chat_message_model.dart';

class ChatController extends GetxController {
  static ChatController get instance => Get.find();

  /// Variables
  static const suggestedPrompts = [
    'Analyze my daily nutrition.',
    'Suggest foods for better digestion.',
    'Create a weekly meal plan.',
    'Check my protein intake.',
    'Help me improve my eating habits.',
  ];

  final _aiRepository = Get.put(AiRepository());
  final input = TextEditingController();
  final scrollController = ScrollController();
  final messages = <ChatMessageModel>[].obs;
  final conversations = <Map<String, dynamic>>[].obs;
  final sending = false.obs;
  final loadingHistory = false.obs;
  final language = Rxn<AppLanguage>(); // null = follow settings / auto-detect
  String? conversationId;
  String? _lastFailedMessage;

  @override
  void onInit() {
    super.onInit();
    loadConversations();
  }

  /// -- Send a message to the AI Health Agent
  Future<void> sendMessage([String? text]) async {
    final message = (text ?? input.text).trim();
    if (message.isEmpty || sending.value) return;
    if (text == null) input.clear();

    messages.add(ChatMessageModel(isUser: true, content: message, createdAt: DateTime.now()));
    _scrollToEnd();
    sending.value = true;
    try {
      final result = await _aiRepository.sendMessage(
        message: message,
        conversationId: conversationId,
        language: language.value?.code,
      );
      conversationId = result['conversation_id'] as String?;
      final safety = (result['safety'] as Map?) ?? const {};
      messages.add(
        ChatMessageModel(
          isUser: false,
          content: result['reply'] as String? ?? '',
          createdAt: DateTime.now(),
          safetyLevel: safety['level'] as String?,
        ),
      );
      _lastFailedMessage = null;
    } catch (e) {
      // Keep the user's text so it can be retried; never invent an answer.
      _lastFailedMessage = message;
      messages.add(
        ChatMessageModel(
          isUser: false,
          content: XExceptionHandler.message(e),
          createdAt: DateTime.now(),
          isError: true,
        ),
      );
    } finally {
      sending.value = false;
      _scrollToEnd();
    }
  }

  /// -- Retry the message that failed
  void retryLast() {
    final message = _lastFailedMessage;
    if (message == null || sending.value) return;
    // Remove the failed pair (user bubble + error bubble) before sending again.
    if (messages.isNotEmpty && messages.last.isError) messages.removeLast();
    if (messages.isNotEmpty && messages.last.isUser) messages.removeLast();
    sendMessage(message);
  }

  bool get canRetry => _lastFailedMessage != null;

  /// -- Conversations
  void newConversation() {
    conversationId = null;
    _lastFailedMessage = null;
    messages.clear();
  }

  Future<void> loadConversations() async {
    try {
      conversations.assignAll(await _aiRepository.fetchConversations());
    } catch (_) {
      // History is optional; the chat still works without it.
    }
  }

  Future<void> openConversation(String id) async {
    try {
      loadingHistory.value = true;
      final history = await _aiRepository.fetchMessages(id);
      conversationId = id;
      _lastFailedMessage = null;
      messages.assignAll(history);
      _scrollToEnd();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not open chat'.tr, message: XExceptionHandler.message(e));
    } finally {
      loadingHistory.value = false;
    }
  }

  /// -- Permanently delete the current conversation
  Future<void> clearConversation() async {
    final id = conversationId;
    try {
      if (id != null) await _aiRepository.deleteConversation(id);
      newConversation();
      await loadConversations();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not clear chat'.tr, message: XExceptionHandler.message(e));
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void onClose() {
    input.dispose();
    scrollController.dispose();
    super.onClose();
  }
}
