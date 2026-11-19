import 'package:get/get.dart';

import '../../../data/repositories/family/family_invitation_repository.dart';
import '../../../data/repositories/family/family_repository.dart';
import '../controllers/family_controller.dart';

/// -- Dependencies of the Family screens.
/// Home already keeps a FamilyController for the signed-in area; the Family screens reuse it.
class FamilyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => FamilyRepository(), fenix: true);
    Get.lazyPut(() => FamilyInvitationRepository(), fenix: true);
    if (!Get.isRegistered<FamilyController>()) Get.lazyPut(() => FamilyController());
  }
}
