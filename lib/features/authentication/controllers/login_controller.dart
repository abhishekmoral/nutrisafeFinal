import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/authentication/authentication_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../screens/signup/verify_email.dart';

class LoginController extends GetxController {
  static LoginController get instance => Get.find();

  /// Variables
  final hidePassword = true.obs;
  final loading = false.obs;
  final email = TextEditingController();
  final password = TextEditingController();
  GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();

  /// -- Email and Password SignIn
  Future<void> emailAndPasswordSignIn() async {
    if (!loginFormKey.currentState!.validate()) return;
    try {
      loading.value = true;
      // The auth listener in AuthenticationRepository redirects after sign-in.
      await AuthenticationRepository.instance.loginWithEmailAndPassword(
        email.text.trim(),
        password.text,
      );
    } on AuthException catch (e) {
      // An unverified account cannot sign in: take the user to the screen where the
      // verification email can be sent again instead of only showing an error.
      final notConfirmed =
          e.code == 'email_not_confirmed' || e.message.toLowerCase().contains('email not confirmed');
      if (notConfirmed) {
        XLoaders.warningSnackBar(
          title: 'Verify your email first'.tr,
          message: 'Open the link in the email we sent you, or send a new one from this screen.'.tr,
        );
        Get.to(() => VerifyEmailScreen(email: email.text.trim()));
      } else {
        XLoaders.errorSnackBar(title: 'Sign in failed'.tr, message: XExceptionHandler.message(e));
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Sign in failed'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  /// -- Google SignIn
  Future<void> googleSignIn() async {
    try {
      await AuthenticationRepository.instance.signInWithGoogle();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Google sign in failed'.tr, message: XExceptionHandler.message(e));
    }
  }

  @override
  void onClose() {
    email.dispose();
    password.dispose();
    super.onClose();
  }
}
