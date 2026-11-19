import 'package:flutter/material.dart';

import '../../constants/colors.dart';

class XChipTheme {
  XChipTheme._();

  /// --------- Light Theme.
  static ChipThemeData lightChipTheme = ChipThemeData(
    disabledColor: Colors.grey.withValues(alpha: 0.4),
    labelStyle: const TextStyle(color: Colors.black),
    selectedColor: XColors.primary,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    checkmarkColor: Colors.white,
  );

  /// ---- Dark Theme
  static ChipThemeData darkChipTheme = const ChipThemeData(
    disabledColor: XColors.darkerGrey,
    labelStyle: TextStyle(color: Colors.white),
    selectedColor: XColors.primary,
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    checkmarkColor: Colors.white,
  );
}
