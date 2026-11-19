import 'dart:ui';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../constants/enums.dart';

/// -- The app language: remembered on this phone and kept in the account (user_settings.preferred_language).
class XLanguageHelper {
  XLanguageHelper._();

  static const _storageKey = 'app_language';
  static final _storage = GetStorage();

  /// The language picked on this phone, or null when the user never picked one here.
  static AppLanguage? get chosen {
    final code = _storage.read<String>(_storageKey);
    return code == null ? null : AppLanguage.fromCode(code);
  }

  /// The language to show now: the one picked here, else the phone's own language when we support it.
  static AppLanguage get current => chosen ?? _deviceLanguage;

  static AppLanguage get _deviceLanguage {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return AppLanguage.values.firstWhere(
      (l) => l != AppLanguage.hinglish && l.locale.languageCode == code,
      orElse: () => AppLanguage.english,
    );
  }

  /// Load month and day names for every language and use the current one for dates.
  static Future<void> init() async {
    await initializeDateFormatting();
    Intl.defaultLocale = current.locale.toString();
  }

  static List<Locale> get supportedLocales => [for (final l in AppLanguage.values) l.locale];

  /// Switch every screen to [language] and remember it on this phone.
  static Future<void> apply(AppLanguage language) async {
    await _storage.write(_storageKey, language.code);
    Intl.defaultLocale = language.locale.toString(); // month and day names
    if (Get.locale != language.locale) await Get.updateLocale(language.locale);
  }

  /// After sign-in: a language picked on this phone wins (returned so the caller can save it to the
  /// account); otherwise the account's language is used.
  static Future<AppLanguage?> syncWithAccount(String? accountCode) async {
    final local = chosen;
    if (local != null) return local.code == accountCode ? null : local;
    if (accountCode != null) await apply(AppLanguage.fromCode(accountCode));
    return null;
  }
}
