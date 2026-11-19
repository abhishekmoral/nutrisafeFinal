import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class XCheckBoxTheme {
  XCheckBoxTheme._();

  /// --------- Light Theme.
  static CheckboxThemeData lightCheckBoxTheme = _build(Colors.black);

  /// ---- Dark Theme
  static CheckboxThemeData darkCheckBoxTheme = _build(Colors.white);

  static CheckboxThemeData _build(Color unselectedCheck) {
    return CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      checkColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? Colors.white : unselectedCheck;
      }),
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected) ? XColors.primary : Colors.transparent;
      }),
    );
  }
}
