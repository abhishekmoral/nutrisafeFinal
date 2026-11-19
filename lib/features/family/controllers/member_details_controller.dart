import 'package:get/get.dart';

import '../../../data/repositories/family/family_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../../nutrition/models/nutrition_values.dart';
import '../../personalization/models/user_model.dart';
import '../models/diary_subject.dart';
import '../models/family_member_model.dart';
import 'family_controller.dart';

/// -- Another adult in my family: what I share with them, and what they share with me.
class MemberDetailsController extends GetxController {
  MemberDetailsController({required this.member});

  final FamilyMemberModel member;

  /// Variables
  final _repository = Get.put(FamilyRepository());
  final iShare = <String>{}.obs; // scopes I grant to them
  final theyShare = <String>{}.obs; // scopes they grant to me
  final sharedProfile = Rxn<UserModel>();
  final sharedAllergies = <String>[].obs;
  final today = Rxn<NutritionValues>();
  final loading = true.obs;
  final saving = RxnString(); // scope being saved

  bool get isMe => member.userId == _repository.uid;

  bool theyAllow(String scope) => theyShare.contains(scope);

  /// Their diary, with exactly the actions they allow me.
  DiarySubject get diarySubject => DiarySubject.sharedAdult(
    name: member.displayName,
    ownerId: member.userId,
    canAdd: theyAllow(FamilyScope.addFood),
    canEdit: theyAllow(FamilyScope.editFood),
    canDelete: theyAllow(FamilyScope.deleteFood),
  );

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    if (isMe) {
      loading.value = false;
      return;
    }
    try {
      final (mine, theirs) = await _repository.fetchPermissionsWith(member.userId);
      iShare.assignAll(mine);
      theyShare.assignAll(theirs);

      sharedProfile.value = theyAllow(FamilyScope.viewProfile) ? await _repository.fetchSharedProfile(member.userId) : null;
      sharedAllergies.assignAll(
        theyAllow(FamilyScope.viewAllergies) ? await _repository.fetchAllergies(ownerId: member.userId) : const [],
      );
      if (theyAllow(FamilyScope.viewInsights) || theyAllow(FamilyScope.viewFoodDiary)) {
        final now = DateTime.now();
        final rows = await _repository.fetchDailyTotals(ownerId: member.userId, from: now, to: now);
        today.value = rows.isEmpty ? NutritionValues.empty : NutritionValues.fromJson(rows.first);
      } else {
        today.value = null;
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load sharing settings'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  /// Turn one of my sharing permissions for this member on or off.
  Future<void> setShare(String scope, bool granted) async {
    final familyId = Get.isRegistered<FamilyController>() ? FamilyController.instance.familyId : null;
    if (familyId == null || saving.value != null) return;
    final previous = iShare.contains(scope);
    granted ? iShare.add(scope) : iShare.remove(scope);
    saving.value = scope;
    try {
      await _repository.setPermission(familyId: familyId, granteeId: member.userId, scope: scope, granted: granted);
    } catch (e) {
      previous ? iShare.add(scope) : iShare.remove(scope);
      XLoaders.errorSnackBar(title: 'Could not update sharing'.tr, message: XExceptionHandler.message(e));
    } finally {
      saving.value = null;
    }
  }
}
