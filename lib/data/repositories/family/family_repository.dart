import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/family/models/diary_subject.dart';
import '../../../features/family/models/family_member_model.dart';
import '../../../features/family/models/managed_profile_model.dart';
import '../../../features/nutrition/models/meal_entry_model.dart';
import '../../../features/personalization/models/user_model.dart';
import '../../../utils/helpers/helper_function.dart';

/// -- Family, members, managed profiles, carers and sharing permissions.
/// Every rule (who may see or change what) is enforced by the database; this class only asks.
class FamilyRepository extends GetxController {
  static FamilyRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  String get uid => _supabase.auth.currentUser!.id;

  /* ------------------------------------------------------------------ Family */

  /// The family I belong to (an account belongs to at most one): {id, name, role}.
  Future<Map<String, dynamic>?> fetchMyFamily() async {
    final row = await _supabase
        .from('family_members')
        .select('role, families(id, name)')
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null || row['families'] == null) return null;
    return {...Map<String, dynamic>.from(row['families'] as Map), 'role': row['role']};
  }

  /// The database makes the creator the Family Admin.
  Future<void> createFamily(String name) async {
    await _supabase.from('families').insert({'name': name, 'created_by': uid});
  }

  Future<List<FamilyMemberModel>> fetchMembers(String familyId) async {
    final rows = await _supabase.rpc('get_family_members', params: {'p_family': familyId});
    return (rows as List).map((e) => FamilyMemberModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Leave the family (my own id) or, as admin, remove another member.
  Future<void> removeMember(String familyId, String userId) async {
    await _supabase.from('family_members').delete().eq('family_id', familyId).eq('user_id', userId);
  }

  /* ------------------------------------------------------------------ Sharing permissions */

  /// ({what I share with them}, {what they share with me})
  Future<(Set<String>, Set<String>)> fetchPermissionsWith(String otherUserId) async {
    final rows = await _supabase
        .from('family_permissions')
        .select('owner_id, grantee_id, scope')
        .or('and(owner_id.eq.$uid,grantee_id.eq.$otherUserId),and(owner_id.eq.$otherUserId,grantee_id.eq.$uid)');
    final mine = <String>{};
    final theirs = <String>{};
    for (final row in rows) {
      (row['owner_id'] == uid ? mine : theirs).add(row['scope'] as String);
    }
    return (mine, theirs);
  }

  Future<void> setPermission({
    required String familyId,
    required String granteeId,
    required String scope,
    required bool granted,
  }) async {
    if (granted) {
      await _supabase.from('family_permissions').upsert({
        'family_id': familyId,
        'owner_id': uid,
        'grantee_id': granteeId,
        'scope': scope,
      }, onConflict: 'owner_id,grantee_id,scope');
    } else {
      await _supabase
          .from('family_permissions')
          .delete()
          .eq('owner_id', uid)
          .eq('grantee_id', granteeId)
          .eq('scope', scope);
    }
  }

  /// Another adult's profile, only returned if they share "View profile" with me.
  Future<UserModel?> fetchSharedProfile(String userId) async {
    final row = await _supabase.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : UserModel.fromJson(row);
  }

  /* ------------------------------------------------------------------ Managed profiles */

  Future<List<ManagedProfileModel>> fetchManagedProfiles(String familyId) async {
    final rows = await _supabase.rpc('get_family_managed_profiles', params: {'p_family': familyId});
    return (rows as List)
        .map((e) => ManagedProfileModel.fromListJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Details; null when I am not a guardian or caregiver of this profile.
  Future<ManagedProfileModel?> fetchManagedProfile(String id) async {
    final row = await _supabase.from('child_profiles').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final role = await _supabase
        .from('guardian_assignments')
        .select('role')
        .eq('child_id', id)
        .eq('guardian_id', uid)
        .maybeSingle();
    return ManagedProfileModel.fromJson(row, myRole: role?['role'] as String?);
  }

  /// Created in one step on the server (family admin only). No login account is created.
  Future<String> createManagedProfile({
    required String fullName,
    required DateTime dateOfBirth,
    String? gender,
    String? relationship,
    String? dietaryPreference,
    List<String> allergies = const [],
    String? notes,
  }) async {
    final id = await _supabase.rpc('create_managed_profile', params: {
      'p_full_name': fullName,
      'p_date_of_birth': XHelperFunctions.toDbDate(dateOfBirth),
      'p_gender': gender,
      'p_relationship': relationship,
      'p_dietary_preference': dietaryPreference,
      'p_allergies': allergies,
      'p_notes': notes,
    });
    return id as String;
  }

  Future<void> updateManagedProfile({
    required String id,
    required String fullName,
    required DateTime dateOfBirth,
    String? gender,
    String? relationship,
    String? dietaryPreference,
    String? notes,
  }) async {
    await _supabase.from('child_profiles').update({
      'full_name': fullName,
      'date_of_birth': XHelperFunctions.toDbDate(dateOfBirth),
      'gender': gender,
      'relationship': relationship,
      'dietary_preference': dietaryPreference,
      'notes': notes,
    }).eq('id', id);
  }

  /// Permanently deletes the profile and all of its records (guardians only).
  Future<void> deleteManagedProfile(String id) async {
    await _supabase.from('child_profiles').delete().eq('id', id);
  }

  /* ------------------------------------------------------------------ Allergies */

  /// Allergies of a diary subject (empty if I may not see them).
  Future<List<String>> fetchAllergies({String? ownerId, String? childId}) async {
    var query = _supabase.from('allergy_profiles').select('allergen');
    query = childId != null
        ? query.eq('child_id', childId)
        : query.eq('owner_id', ownerId ?? uid).isFilter('child_id', null);
    final rows = await query;
    return rows.map((e) => e['allergen'] as String).toList();
  }

  /// Replace a managed profile's allergy list (guardians only).
  Future<void> saveManagedAllergies(String childId, List<String> allergens) async {
    await _supabase.from('allergy_profiles').delete().eq('child_id', childId);
    if (allergens.isEmpty) return;
    await _supabase
        .from('allergy_profiles')
        .insert(allergens.map((a) => {'owner_id': uid, 'child_id': childId, 'allergen': a}).toList());
  }

  /* ------------------------------------------------------------------ Carers */

  Future<List<CarerModel>> fetchCarers(String childId) async {
    final rows = await _supabase.rpc('get_managed_profile_carers', params: {'p_child': childId});
    return (rows as List).map((e) => CarerModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> addCarer(String childId, String userId, String role) async {
    await _supabase.from('guardian_assignments').insert({
      'child_id': childId,
      'guardian_id': userId,
      'assigned_by': uid,
      'role': role,
    });
  }

  Future<void> setCarerRole(String childId, String userId, String role) async {
    await _supabase
        .from('guardian_assignments')
        .update({'role': role})
        .eq('child_id', childId)
        .eq('guardian_id', userId);
  }

  Future<void> removeCarer(String childId, String userId) async {
    await _supabase.from('guardian_assignments').delete().eq('child_id', childId).eq('guardian_id', userId);
  }

  /* ------------------------------------------------------------------ Member food diaries */

  Future<List<MealEntryModel>> fetchEntries(DiarySubject subject, DateTime date) async {
    var query = _supabase.from('meal_entries').select().eq('entry_date', XHelperFunctions.toDbDate(date));
    query = subject.childId != null
        ? query.eq('child_id', subject.childId!)
        : query.eq('owner_id', subject.ownerId!).isFilter('child_id', null);
    final rows = await query.order('consumed_at');
    return rows.map(MealEntryModel.fromJson).toList();
  }

  /// Save an entry in a member's diary. For a managed profile the entry is recorded under
  /// my account with the profile as its subject; for an adult it goes into their own diary.
  Future<void> addEntry(DiarySubject subject, MealEntryModel entry) async {
    final ownerId = subject.childId != null ? uid : subject.ownerId!;
    await _supabase.from('meal_entries').upsert(
      {...entry.toJson(ownerId), 'child_id': subject.childId},
      onConflict: 'owner_id,client_entry_id',
      ignoreDuplicates: true,
    );
  }

  /// Change the amount; nutrition scales with it (it was calculated from the amount).
  Future<void> updateEntryQuantity(MealEntryModel entry, double quantity) async {
    final factor = quantity / entry.quantity;
    await _supabase.from('meal_entries').update({
      'quantity': quantity,
      ...entry.nutrition.scale(factor).toJson(),
    }).eq('id', entry.id!);
  }

  Future<void> deleteEntry(String id) async {
    await _supabase.from('meal_entries').delete().eq('id', id);
  }

  /// Per-day totals for a member's nutrition summary (no individual foods).
  Future<List<Map<String, dynamic>>> fetchDailyTotals({
    String? ownerId,
    String? childId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _supabase.rpc('get_daily_totals', params: {
      'p_owner': ownerId,
      'p_child': childId,
      'p_from': XHelperFunctions.toDbDate(from),
      'p_to': XHelperFunctions.toDbDate(to),
    });
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
