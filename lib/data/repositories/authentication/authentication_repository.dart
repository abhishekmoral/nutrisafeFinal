import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/authentication/screens/login/login.dart';
import '../../../features/authentication/screens/password_configuration/new_password.dart';
import '../../../features/personalization/controllers/user_controller.dart';
import '../../../features/personalization/screens/profile_setup/profile_setup.dart';
import '../../../navigation_menu.dart';
import '../../../utils/constants/api_constants.dart';
import '../../../utils/logging/logger.dart';

class AuthenticationRepository extends GetxController {
  static AuthenticationRepository get instance => Get.find();

  /// Variables
  final _supabase = Supabase.instance.client;
  StreamSubscription<AuthState>? _authSubscription;
  bool _recoveringPassword = false;

  User? get authUser => _supabase.auth.currentUser;

  String get userId => _supabase.auth.currentUser!.id;

  /// Called from main.dart on app launch
  @override
  void onReady() {
    // Google sign-in and email links come back through a deep link -> signedIn event.
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _recoveringPassword = true;
        Get.offAll(() => const NewPasswordScreen());
      } else if (data.event == AuthChangeEvent.signedOut) {
        _recoveringPassword = false;
        screenRedirect();
      } else if (data.event == AuthChangeEvent.signedIn && !_recoveringPassword) {
        screenRedirect();
      }
    });
    screenRedirect();
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  /// Decide which screen to show.
  Future<void> screenRedirect() async {
    if (_supabase.auth.currentSession == null) {
      Get.offAll(() => const LoginScreen());
      return;
    }
    try {
      final user = await UserController.instance.fetchUserRecord();
      await UserController.instance.syncLanguage(onboarded: user.onboardingCompleted);
      if (user.onboardingCompleted) {
        Get.offAll(() => const NavigationMenu());
      } else {
        Get.offAll(() => const ProfileSetupScreen());
      }
    } catch (e) {
      XLoggerHelper.error('Could not load the profile', e);
      Get.offAll(() => const LoginScreen());
    }
  }

  /* ---------------------------- Email & Password sign-in ---------------------------------*/

  /// [EmailAuthentication] - Sign In
  Future<void> loginWithEmailAndPassword(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// [EmailAuthentication] - Register. Returns true when a session exists right away
  /// (email confirmation disabled), false when the user must verify the email first.
  Future<bool> registerWithEmailAndPassword(String email, String password, String fullName) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: XApiConstants.authRedirectUrl,
    );
    return response.session != null;
  }

  /// [EmailVerification] - Resend
  Future<void> resendVerificationEmail(String email) async {
    await _supabase.auth.resend(
      type: OtpType.signup,
      email: email,
      emailRedirectTo: XApiConstants.authRedirectUrl,
    );
  }

  /// [EmailAuthentication] - Forget password
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email, redirectTo: XApiConstants.authRedirectUrl);
  }

  /// Set a new password (user arrives signed-in through the reset link).
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    _recoveringPassword = false;
  }

  /* ---------------------------- Social sign-in ---------------------------------*/

  /// [GoogleAuthentication] - opens the browser, returns through the deep link.
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: XApiConstants.authRedirectUrl,
    );
  }

  /* ---------------------------- Logout & delete ---------------------------------*/

  /// [LogoutUser]
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// [DeleteAccount] - runs on the backend (removes files, data and the auth user).
  Future<void> deleteAccount() async {
    await _supabase.functions.invoke(XApiConstants.deleteAccountFunction);
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }
}
