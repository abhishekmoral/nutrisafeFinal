import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/personalization/models/user_model.dart';

class UserRepository extends GetxController {
  static UserRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  String get _uid => _supabase.auth.currentUser!.id;

  /// -- Profile
  Future<UserModel> fetchUserDetails() async {
    final row = await _supabase.from('profiles').select().eq('id', _uid).maybeSingle();
    final email = _supabase.auth.currentUser?.email ?? '';
    if (row == null) {
      // Safety net: the database trigger normally creates this row at sign-up.
      final created = await _supabase.from('profiles').insert({'id': _uid}).select().single();
      return UserModel.fromJson(created, email: email);
    }
    return UserModel.fromJson(row, email: email);
  }

  Future<void> updateUserDetails(UserModel user) async {
    await _supabase.from('profiles').update(user.toJson()).eq('id', _uid);
  }

  /// -- Settings (language, voice ...)
  Future<Map<String, dynamic>> fetchSettings() async {
    final row = await _supabase.from('user_settings').select().eq('user_id', _uid).maybeSingle();
    return row ?? {'preferred_language': 'en', 'auto_detect_language': true};
  }

  Future<void> updateSettings(Map<String, dynamic> values) async {
    await _supabase.from('user_settings').upsert({'user_id': _uid, ...values});
  }

  /// -- Allergies & intolerances (own profile)
  Future<List<String>> fetchAllergies() async {
    final rows = await _supabase
        .from('allergy_profiles')
        .select('allergen')
        .eq('owner_id', _uid)
        .isFilter('child_id', null);
    return rows.map((e) => e['allergen'] as String).toList();
  }

  Future<List<String>> fetchIntolerances() async {
    final rows = await _supabase
        .from('intolerance_profiles')
        .select('food')
        .eq('owner_id', _uid)
        .isFilter('child_id', null);
    return rows.map((e) => e['food'] as String).toList();
  }

  /// Replace the saved list with [allergens].
  Future<void> saveAllergies(List<String> allergens) async {
    await _supabase.from('allergy_profiles').delete().eq('owner_id', _uid).isFilter('child_id', null);
    if (allergens.isEmpty) return;
    await _supabase
        .from('allergy_profiles')
        .insert(allergens.map((a) => {'owner_id': _uid, 'allergen': a}).toList());
  }

  Future<void> saveIntolerances(List<String> foods) async {
    await _supabase
        .from('intolerance_profiles')
        .delete()
        .eq('owner_id', _uid)
        .isFilter('child_id', null);
    if (foods.isEmpty) return;
    await _supabase
        .from('intolerance_profiles')
        .insert(foods.map((f) => {'owner_id': _uid, 'food': f}).toList());
  }

  /// -- Wellness goals
  Future<List<String>> fetchHealthGoals() async {
    final rows = await _supabase
        .from('user_health_goals')
        .select('goal_type')
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .eq('is_active', true);
    return rows.map((e) => e['goal_type'] as String).toList();
  }

  Future<void> saveHealthGoals(List<String> goalTypes) async {
    await _supabase
        .from('user_health_goals')
        .delete()
        .eq('owner_id', _uid)
        .isFilter('child_id', null);
    if (goalTypes.isEmpty) return;
    await _supabase
        .from('user_health_goals')
        .insert(goalTypes.map((g) => {'owner_id': _uid, 'goal_type': g}).toList());
  }

  /// -- What the AI agent is allowed to read. Missing row = not allowed.
  Future<Map<String, bool>> fetchAiPermissions() async {
    final rows = await _supabase
        .from('ai_user_context_permissions')
        .select('context_type, allowed')
        .eq('owner_id', _uid)
        .isFilter('child_id', null);
    return {for (final r in rows) r['context_type'] as String: r['allowed'] == true};
  }

  Future<void> setAiPermission(String contextType, bool allowed) async {
    await _supabase
        .from('ai_user_context_permissions')
        .delete()
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .eq('context_type', contextType);
    await _supabase.from('ai_user_context_permissions').insert({
      'owner_id': _uid,
      'context_type': contextType,
      'allowed': allowed,
    });
  }

  /// -- Consent records
  Future<void> recordConsent(String consentType, bool granted) async {
    await _supabase.from('user_consents').upsert({
      'user_id': _uid,
      'consent_type': consentType,
      'version': '1',
      'granted': granted,
      'granted_at': granted ? DateTime.now().toUtc().toIso8601String() : null,
      'revoked_at': granted ? null : DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,consent_type,version');
  }
}
