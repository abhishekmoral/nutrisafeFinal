import 'package:get/get.dart';

import '../data/repositories/authentication/authentication_repository.dart';
import '../features/personalization/controllers/user_controller.dart';

class GeneralBindings extends Bindings {
  @override
  void dependencies() {
    Get.put(UserController(), permanent: true);
    Get.put(AuthenticationRepository(), permanent: true);
  }
}
