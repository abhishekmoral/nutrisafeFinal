import 'package:get/get.dart';

import '../../../data/repositories/user/user_repository.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/localization/language_helper.dart';
import '../../../utils/logging/logger.dart';
import '../models/user_model.dart';

class UserController extends GetxController {
  static UserController get instance => Get.find();

  /// Variables
  final userRepository = Get.put(UserRepository());
  Rx<UserModel> user = UserModel.empty().obs;
  final profileLoading = false.obs;

  /// Fetch user record
  Future<UserModel> fetchUserRecord() async {
    try {
      profileLoading.value = true;
      final fetched = await userRepository.fetchUserDetails();
      user(fetched);
      return fetched;
    } finally {
      profileLoading.value = false;
    }
  }

  /// Save changed profile fields
  Future<void> saveUserRecord(UserModel updated) async {
    await userRepository.updateUserDetails(updated);
    user(updated);
    user.refresh();
  }

  /// -- App language
  /// After sign-in: a new account takes the language the app already shows; an existing account keeps
  /// its language unless one was picked on this phone.
  Future<void> syncLanguage({required bool onboarded}) async {
    try {
      if (!onboarded) {
        await userRepository.updateSettings({'preferred_language': XLanguageHelper.current.code});
        return;
      }
      final settings = await userRepository.fetchSettings();
      final toSave = await XLanguageHelper.syncWithAccount(settings['preferred_language'] as String?);
      if (toSave != null) await userRepository.updateSettings({'preferred_language': toSave.code});
    } catch (e) {
      XLoggerHelper.warning('Could not sync the app language: ${e.runtimeType}');
    }
  }

  /// Switch the app to [language] now and keep it in the account (also the AI agent's reply language).
  Future<void> setLanguage(AppLanguage language) async {
    await XLanguageHelper.apply(language);
    await userRepository.updateSettings({'preferred_language': language.code});
  }
}
