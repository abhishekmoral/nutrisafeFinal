import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../data/repositories/authentication/authentication_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../screens/password_configuration/reset_password.dart';

class ForgetPasswordController extends GetxController {
  static ForgetPasswordController get instance => Get.find();

  /// Variables
  final loading = false.obs;
  final email = TextEditingController();
  GlobalKey<FormState> forgetPasswordFormKey = GlobalKey<FormState>();

  /// Send Reset Password Email
  Future<void> sendPasswordResetEmail() async {
    if (!forgetPasswordFormKey.currentState!.validate()) return;
    await _send(email.text.trim(), openNextScreen: true);
  }

  Future<void> resendPasswordResetEmail(String email) async {
    await _send(email, openNextScreen: false);
  }

  Future<void> _send(String email, {required bool openNextScreen}) async {
    try {
      loading.value = true;
      await AuthenticationRepository.instance.sendPasswordResetEmail(email);
      XLoaders.successSnackBar(title: 'Email sent'.tr, message: 'Check your inbox for the reset link.'.tr);
      if (openNextScreen) Get.to(() => ResetPasswordScreen(email: email));
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not send email'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  @override
  void onClose() {
    email.dispose();
    super.onClose();
  }
}
