import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'bindings/general_bindings.dart';
import 'utils/constants/colors.dart';
import 'utils/constants/enums.dart';
import 'utils/constants/text_strings.dart';
import 'utils/localization/language_helper.dart';
import 'utils/localization/translations.dart';
import 'utils/theme/theme.dart';

/// -- Use this Class to Setup themes, initial Bindings, any animations and much more.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: XTexts.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: XAppTheme.lightTheme,
      darkTheme: XAppTheme.darkTheme,
      initialBinding: GeneralBindings(),

      /// Languages: every screen follows the language picked in the app (Urdu right to left)
      translations: XTranslations.current,
      locale: XLanguageHelper.current.locale,
      fallbackLocale: AppLanguage.english.locale,
      supportedLocales: XLanguageHelper.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      /// Show a loader while AuthenticationRepository decides which screen to open.
      home: const Scaffold(
        backgroundColor: XColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}
