import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../constants/enums.dart';

/// -- All app texts in every language, loaded once at start-up from assets/translations/{code}.json.
/// The English text itself is the key, so a text with no translation simply shows in English.
class XTranslations extends Translations {
  XTranslations._(this._keys);

  final Map<String, Map<String, String>> _keys;

  /// Loaded by main() before the app starts. Empty (English only) until then, so a hot reload never breaks.
  static XTranslations current = XTranslations._(const {});

  @override
  Map<String, Map<String, String>> get keys => _keys;

  /// GetX looks up "language_COUNTRY" (for example hi_null, en_IN) first, then any map of the same language.
  static String localeKey(Locale locale) =>
      '${locale.languageCode}_${locale.countryCode}';

  static Future<XTranslations> load() async {
    final keys = <String, Map<String, String>>{};
    for (final language in AppLanguage.values) {
      if (language == AppLanguage.english) continue;
      try {
        final raw = await rootBundle.loadString('assets/translations/${language.code}.json');
        keys[localeKey(language.locale)] = Map<String, String>.from(jsonDecode(raw) as Map);
      } catch (_) {
        // Not translated yet: this language shows the English texts.
      }
    }

    // English and Hinglish are both "en". An explicit English map stops English from borrowing Hinglish.
    keys[localeKey(AppLanguage.english.locale)] = {
      for (final map in keys.values)
        for (final key in map.keys) key: key,
    };
    return current = XTranslations._(keys);
  }
}

extension XTranslate on String {
  /// Translates a text with {placeholders} and fills them in:
  /// `'Added to {meal}'.trf({'meal': meal.label})`
  String trf(Map<String, Object?> params) {
    var text = tr;
    params.forEach((key, value) => text = text.replaceAll('{$key}', '${value ?? ''}'));
    return text;
  }
}
