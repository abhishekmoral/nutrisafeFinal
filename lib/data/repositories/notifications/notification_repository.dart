import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// -- In-app notifications (family invitations, permission changes ...).
class NotificationRepository extends GetxController {
  static NotificationRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  String get _uid => _supabase.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> fetchRecent() async {
    return _supabase
        .from('notifications')
        .select('id, title, body, created_at, read_at')
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(50);
  }

  Future<int> unreadCount() async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', _uid)
        .isFilter('read_at', null)
        .count(CountOption.exact);
    return response.count;
  }

  Future<void> markAllRead() async {
    await _supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _uid)
        .isFilter('read_at', null);
  }
}
