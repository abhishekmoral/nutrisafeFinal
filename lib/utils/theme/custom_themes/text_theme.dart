import 'package:flutter/material.dart';

class XTextTheme {
  XTextTheme._();

  /// --------- Light Theme.
  static TextTheme lightTextTheme = _build(Colors.black);

  /// ---- Dark Theme
  static TextTheme darkTextTheme = _build(Colors.white);

  static TextTheme _build(Color color) {
    return TextTheme(
      headlineLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, color: color),
      headlineMedium: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600, color: color),
      headlineSmall: TextStyle(fontSize: 18.0, fontWeight: FontWeight.w600, color: color),
      titleLarge: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600, color: color),
      titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, color: color),
      titleSmall: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w400, color: color),
      bodyLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, color: color),
      bodyMedium: TextStyle(fontSize: 14.0, fontWeight: FontWeight.normal, color: color),
      bodySmall: TextStyle(
        fontSize: 14.0,
        fontWeight: FontWeight.w500,
        color: color.withValues(alpha: 0.6),
      ),
      labelLarge: TextStyle(fontSize: 12.0, fontWeight: FontWeight.normal, color: color),
      labelMedium: TextStyle(
        fontSize: 12.0,
        fontWeight: FontWeight.normal,
        color: color.withValues(alpha: 0.6),
      ),
    );
  }
}
