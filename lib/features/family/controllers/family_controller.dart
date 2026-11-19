import 'package:get/get.dart';

import '../../../data/repositories/family/family_invitation_repository.dart';
import '../../../data/repositories/family/family_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/family_invitation_model.dart';
import '../models/family_member_model.dart';
import '../models/managed_profile_model.dart';
import '../../../utils/localization/translations.dart';

/// -- The Family screen: my family, its connected accounts, managed profiles and invitations.
class FamilyController extends GetxController {
  static FamilyController get instance => Get.find();

  /// Variables
  final _familyRepository = Get.put(FamilyRepository());
  final _invitationRepository = Get.put(FamilyInvitationRepository());

  final family = Rxn<Map<String, dynamic>>(); // id, name, role
  final members = <FamilyMemberModel>[].obs;
  final managedProfiles = <ManagedProfileModel>[].obs;
  final receivedInvitations = <FamilyInvitationModel>[].obs;
  final sentInvitations = <FamilyInvitationModel>[].obs;
  final loading = true.obs;
  final loadError = RxnString();
  final working = false.obs;

  String get myId => _familyRepository.uid;
  bool get hasFamily => family.value != null;
  bool get isAdmin => family.value?['role'] == 'admin';
  String? get familyId => family.value?['id'] as String?;
  String get familyName => family.value?['name'] as String? ?? 'My Family'.tr;
  int get memberCount => members.length + managedProfiles.length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      loadError.value = null;
      final results = await Future.wait([
        _familyRepository.fetchMyFamily(),
        _invitationRepository.fetchReceived(),
      ]);
      family.value = results[0] as Map<String, dynamic>?;
      receivedInvitations.assignAll(results[1] as List<FamilyInvitationModel>);

      final id = familyId;
      if (id == null) {
        members.clear();
        managedProfiles.clear();
        sentInvitations.clear();
      } else {
        final data = await Future.wait([
          _familyRepository.fetchMembers(id),
          _familyRepository.fetchManagedProfiles(id),
          isAdmin ? _invitationRepository.fetchSent() : Future.value(<FamilyInvitationModel>[]),
        ]);
        members.assignAll(data[0] as List<FamilyMemberModel>);
        managedProfiles.assignAll(data[1] as List<ManagedProfileModel>);
        sentInvitations.assignAll(data[2] as List<FamilyInvitationModel>);
      }
    } catch (e) {
      loadError.value = XExceptionHandler.message(e);
    } finally {
      loading.value = false;
    }
  }

  /// Runs an action with a busy flag, an error message and a reload.
  Future<bool> _run(Future<void> Function() action, String errorTitle, {String? success}) async {
    if (working.value) return false;
    try {
      working.value = true;
      await action();
      if (success != null) XLoaders.successSnackBar(title: success);
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: errorTitle, message: XExceptionHandler.message(e));
      return false;
    } finally {
      working.value = false;
      await load();
    }
  }

  Future<bool> createFamily(String name) =>
      _run(() => _familyRepository.createFamily(name), 'Could not create the family'.tr, success: 'Family created'.tr);

  Future<void> respondToInvitation(FamilyInvitationModel invitation, {required bool accept}) async {
    if (working.value) return;
    try {
      working.value = true;
      final status = await _invitationRepository.respond(invitation.id, accept: accept);
      switch (status) {
        case 'accepted':
          XLoaders.successSnackBar(
            title: 'You joined {family}'.trf({'family': invitation.familyName ?? 'the family'.tr}),
          );
        case 'rejected':
          XLoaders.successSnackBar(title: 'Invitation declined'.tr);
        case 'expired':
          XLoaders.warningSnackBar(
            title: 'This invitation has expired'.tr,
            message: 'Ask the family admin to send a new one.'.tr,
          );
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not answer the invitation'.tr, message: XExceptionHandler.message(e));
    } finally {
      working.value = false;
      await load();
    }
  }

  Future<bool> revokeInvitation(FamilyInvitationModel invitation) =>
      _run(() => _invitationRepository.revoke(invitation.id), 'Could not cancel'.tr, success: 'Invitation cancelled'.tr);

  Future<bool> removeMember(FamilyMemberModel member) => _run(
    () => _familyRepository.removeMember(familyId!, member.userId),
    'Could not remove {displayName}'.trf({'displayName': member.displayName}),
    success: '{displayName} was removed'.trf({'displayName': member.displayName}),
  );

  Future<bool> leaveFamily() =>
      _run(() => _familyRepository.removeMember(familyId!, myId), 'Could not leave the family'.tr, success: 'You left the family'.tr);
}
