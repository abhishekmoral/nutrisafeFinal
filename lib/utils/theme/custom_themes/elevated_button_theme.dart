import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class XElevatedButtonTheme {
  XElevatedButtonTheme._();

  /// --------- Light Theme.
  static final lightElevatedButtonTheme = ElevatedButtonThemeData(style: _style());

  /// ---- Dark Theme
  static final darkElevatedButtonTheme = ElevatedButtonThemeData(style: _style());

  static ButtonStyle _style() {
    return ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: XColors.primary,
      disabledBackgroundColor: Colors.grey,
      disabledForegroundColor: Colors.white70,
      side: const BorderSide(color: XColors.primary),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      textStyle: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
