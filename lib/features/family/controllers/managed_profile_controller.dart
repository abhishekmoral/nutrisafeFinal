import 'package:get/get.dart';

import '../../../data/repositories/family/family_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/family_member_model.dart';
import '../models/managed_profile_model.dart';
import '../../nutrition/models/nutrition_values.dart';
import 'family_controller.dart';
import '../../../utils/localization/translations.dart';

/// -- Details of one managed profile: personal details, allergies, carers and a nutrition summary.
class ManagedProfileController extends GetxController {
  ManagedProfileController({required this.profileId});

  final String profileId;

  /// Variables
  final _repository = Get.put(FamilyRepository());
  final profile = Rxn<ManagedProfileModel>();
  final allergies = <String>[].obs;
  final carers = <CarerModel>[].obs;
  final today = Rxn<NutritionValues>();
  final loggedDaysThisWeek = 0.obs;
  final loading = true.obs;
  final noAccess = false.obs;
  final working = false.obs;

  String get myId => _repository.uid;
  bool get isGuardian => profile.value?.isGuardian ?? false;

  /// Family members who could become a guardian or caregiver (not yet one).
  List<FamilyMemberModel> get possibleCarers {
    if (!Get.isRegistered<FamilyController>()) return [];
    final assigned = carers.map((c) => c.userId).toSet();
    return FamilyController.instance.members.where((m) => !assigned.contains(m.userId)).toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final details = await _repository.fetchManagedProfile(profileId);
      if (details == null) {
        noAccess.value = true;
        return;
      }
      profile.value = details;
      final now = DateTime.now();
      final results = await Future.wait([
        _repository.fetchAllergies(childId: profileId),
        _repository.fetchCarers(profileId),
        _repository.fetchDailyTotals(childId: profileId, from: now.subtract(const Duration(days: 6)), to: now),
      ]);
      allergies.assignAll(results[0] as List<String>);
      carers.assignAll(results[1] as List<CarerModel>);
      final days = results[2] as List<Map<String, dynamic>>;
      loggedDaysThisWeek.value = days.length;
      final todayKey = DateTime(now.year, now.month, now.day).toIso8601String().substring(0, 10);
      final todayRow = days.where((d) => d['day'] == todayKey).toList();
      today.value = todayRow.isEmpty ? NutritionValues.empty : NutritionValues.fromJson(todayRow.first);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load the profile'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

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

  Future<bool> addCarer(FamilyMemberModel member, String role) => _run(
    () => _repository.addCarer(profileId, member.userId, role),
    'Could not add {displayName}'.trf({'displayName': member.displayName}),
    success: (role == 'guardian' ? '{displayName} is now a guardian' : '{displayName} is now a caregiver')
        .trf({'displayName': member.displayName}),
  );

  Future<bool> setCarerRole(CarerModel carer, String role) => _run(
    () => _repository.setCarerRole(profileId, carer.userId, role),
    'Could not change the role'.tr,
  );

  /// Remove a carer, or stop caring myself. A profile always keeps one guardian (checked by the server).
  Future<bool> removeCarer(CarerModel carer) async {
    final ok = await _run(() => _repository.removeCarer(profileId, carer.userId), 'Could not remove'.tr);
    if (ok && carer.userId == myId) {
      if (Get.isRegistered<FamilyController>()) FamilyController.instance.load();
      Get.back();
    }
    return ok;
  }

  Future<void> deleteProfile() async {
    try {
      working.value = true;
      await _repository.deleteManagedProfile(profileId);
      if (Get.isRegistered<FamilyController>()) FamilyController.instance.load();
      Get.back();
      XLoaders.successSnackBar(title: 'Member profile deleted'.tr);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not delete the profile'.tr, message: XExceptionHandler.message(e));
    } finally {
      working.value = false;
    }
  }
}
