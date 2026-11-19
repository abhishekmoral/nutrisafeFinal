import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'utils/constants/api_constants.dart';
import 'utils/localization/language_helper.dart';
import 'utils/localization/translations.dart';

/// -------- Entry point of Flutter App --------.
Future<void> main() async {
  /// Widgets Binding
  WidgetsFlutterBinding.ensureInitialized();

  /// Local storage (remembers the app language) and every translation
  await GetStorage.init();
  await XLanguageHelper.init();
  await XTranslations.load();

  /// Initialize Supabase (URL + publishable key only; secrets stay on the backend)
  await Supabase.initialize(
    url: XApiConstants.supabaseUrl,
    publishableKey: XApiConstants.supabasePublishableKey,
  );

  runApp(const App());
}
