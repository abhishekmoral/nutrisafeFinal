import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/family/models/family_invitation_model.dart';

/// -- Finding accounts by NutriSafe ID and the invitation workflow.
/// All checks (admin only, no duplicates, only the invitee answers, expiry) run on the server.
class FamilyInvitationRepository extends GetxController {
  static FamilyInvitationRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  /// Null when no account has this ID.
  Future<AccountLookupModel?> findAccount(String nutrisafeId) async {
    final rows = await _supabase.rpc('find_account_by_nutrisafe_id', params: {'p_nutrisafe_id': nutrisafeId});
    final list = rows as List;
    return list.isEmpty ? null : AccountLookupModel.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  Future<void> invite(String nutrisafeId) async {
    await _supabase.rpc('invite_to_family', params: {'p_nutrisafe_id': nutrisafeId});
  }

  /// Invitations sent to me that I can still answer.
  Future<List<FamilyInvitationModel>> fetchReceived() async {
    final rows = await _supabase.rpc('get_my_family_invitations');
    return (rows as List)
        .map((e) => FamilyInvitationModel.received(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Invitations my family sent (family admin only; empty otherwise).
  Future<List<FamilyInvitationModel>> fetchSent() async {
    final rows = await _supabase.rpc('get_family_invitations');
    return (rows as List).map((e) => FamilyInvitationModel.sent(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Returns the new status: accepted, rejected or expired.
  Future<String> respond(String invitationId, {required bool accept}) async {
    final status = await _supabase.rpc(
      'respond_to_family_invitation',
      params: {'p_invitation': invitationId, 'p_accept': accept},
    );
    return status as String;
  }

  Future<void> revoke(String invitationId) async {
    await _supabase.rpc('revoke_family_invitation', params: {'p_invitation': invitationId});
  }
}
