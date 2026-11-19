import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'custom_themes/appbar_theme.dart';
import 'custom_themes/bottom_sheet_theme.dart';
import 'custom_themes/checkbox_theme.dart';
import 'custom_themes/chip_theme.dart';
import 'custom_themes/elevated_button_theme.dart';
import 'custom_themes/outlined_button_theme.dart';
import 'custom_themes/text_field_theme.dart';
import 'custom_themes/text_theme.dart';

class XAppTheme {
  XAppTheme._();

  /// Light Theme.
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: XColors.primary,
    colorScheme: ColorScheme.fromSeed(seedColor: XColors.primary, brightness: Brightness.light),
    textTheme: XTextTheme.lightTextTheme,
    chipTheme: XChipTheme.lightChipTheme,
    scaffoldBackgroundColor: XColors.lightBackground,
    appBarTheme: XAppBarTheme.lightAppBarTheme,
    checkboxTheme: XCheckBoxTheme.lightCheckBoxTheme,
    bottomSheetTheme: XBottomSheetTheme.lightBottomSheetTheme,
    elevatedButtonTheme: XElevatedButtonTheme.lightElevatedButtonTheme,
    outlinedButtonTheme: XOutlinedButtonTheme.lightOutLinedButtonTheme,
    inputDecorationTheme: XTextFormFieldTheme.lightInputDecorationTheme,
  );

  /// Dark Theme.
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: XColors.primary,
    colorScheme: ColorScheme.fromSeed(seedColor: XColors.primary, brightness: Brightness.dark),
    textTheme: XTextTheme.darkTextTheme,
    chipTheme: XChipTheme.darkChipTheme,
    scaffoldBackgroundColor: XColors.darkBackground,
    appBarTheme: XAppBarTheme.darkAppBarTheme,
    checkboxTheme: XCheckBoxTheme.darkCheckBoxTheme,
    bottomSheetTheme: XBottomSheetTheme.darkBottomSheetTheme,
    elevatedButtonTheme: XElevatedButtonTheme.darkElevatedButtonTheme,
    outlinedButtonTheme: XOutlinedButtonTheme.darkOutLinedButtonTheme,
    inputDecorationTheme: XTextFormFieldTheme.darkInputDecorationTheme,
  );
}
