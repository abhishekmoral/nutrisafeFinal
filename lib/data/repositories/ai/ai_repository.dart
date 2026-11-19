import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/ai_agent/models/chat_message_model.dart';
import '../../../utils/constants/api_constants.dart';

class AiRepository extends GetxController {
  static AiRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  String get _uid => _supabase.auth.currentUser!.id;

  /// -- Ask the AI Health Agent. The AI key lives only in the Edge Function.
  /// Returns { conversation_id, reply, safety: { flagged, level } }.
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? conversationId,
    String? language,
  }) async {
    final response = await _supabase.functions
        .invoke(
          XApiConstants.healthAgentFunction,
          body: {
            'message': message,
            'conversation_id': conversationId,
            'language': language,
            'tz_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
          },
        )
        .timeout(const Duration(seconds: 120));
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// -- Conversations, newest first
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    return _supabase
        .from('ai_conversations')
        .select('id, title, updated_at')
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .order('updated_at', ascending: false)
        .limit(30);
  }

  Future<List<ChatMessageModel>> fetchMessages(String conversationId) async {
    final rows = await _supabase
        .from('ai_messages')
        .select('role, content, metadata, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at');
    return rows.map(ChatMessageModel.fromJson).toList();
  }

  /// -- Deletes the conversation and all its messages (cascade).
  Future<void> deleteConversation(String conversationId) async {
    await _supabase.from('ai_conversations').delete().eq('id', conversationId);
  }
}
