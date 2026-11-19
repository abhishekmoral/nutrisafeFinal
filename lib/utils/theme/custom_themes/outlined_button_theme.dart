import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class XOutlinedButtonTheme {
  XOutlinedButtonTheme._();

  /// --------- Light Theme.
  static final lightOutLinedButtonTheme = OutlinedButtonThemeData(
    style: _style(Colors.black, XColors.borderLight),
  );

  /// ---- Dark Theme
  static final darkOutLinedButtonTheme = OutlinedButtonThemeData(
    style: _style(Colors.white, XColors.borderDark),
  );

  static ButtonStyle _style(Color foreground, Color border) {
    return OutlinedButton.styleFrom(
      elevation: 0,
      foregroundColor: foreground,
      side: BorderSide(color: border),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      textStyle: TextStyle(fontSize: 16, color: foreground, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
