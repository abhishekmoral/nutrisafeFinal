import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/authentication/authentication_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../screens/signup/verify_email.dart';

class SignupController extends GetxController {
  static SignupController get instance => Get.find();

  /// Variables
  final hidePassword = true.obs;
  final privacyPolicy = false.obs;
  final loading = false.obs;
  final fullName = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  GlobalKey<FormState> signupFormKey = GlobalKey<FormState>();

  /// -- SIGNUP
  Future<void> signup() async {
    if (!signupFormKey.currentState!.validate()) return;
    if (!privacyPolicy.value) {
      XLoaders.warningSnackBar(
        title: 'Accept Privacy Policy'.tr,
        message: 'To create an account you must accept the Privacy Policy & Terms of Use.'.tr,
      );
      return;
    }
    try {
      loading.value = true;
      final signedIn = await AuthenticationRepository.instance.registerWithEmailAndPassword(
        email.text.trim(),
        password.text,
        fullName.text.trim(),
      );
      // Without a session the user must confirm the email first.
      if (!signedIn) Get.to(() => VerifyEmailScreen(email: email.text.trim()));
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Sign up failed'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    fullName.dispose();
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
