import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../constants/sizes.dart';

class XTextFormFieldTheme {
  XTextFormFieldTheme._();

  /// --------- Light Theme.
  static InputDecorationTheme lightInputDecorationTheme = _build(
    text: Colors.black,
    border: XColors.borderLight,
    focused: XColors.primary,
  );

  /// ---- Dark Theme
  static InputDecorationTheme darkInputDecorationTheme = _build(
    text: Colors.white,
    border: XColors.borderDark,
    focused: XColors.accent,
  );

  static InputDecorationTheme _build({
    required Color text,
    required Color border,
    required Color focused,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(XSizes.inputFieldRadius),
      borderSide: BorderSide(width: width, color: color),
    );

    return InputDecorationTheme(
      errorMaxLines: 3,
      prefixIconColor: XColors.darkGrey,
      suffixIconColor: XColors.darkGrey,
      labelStyle: TextStyle(fontSize: XSizes.fontSizeSm, color: text),
      hintStyle: TextStyle(fontSize: XSizes.fontSizeSm, color: text.withValues(alpha: 0.5)),
      floatingLabelStyle: TextStyle(color: text.withValues(alpha: 0.8)),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(focused, 1.5),
      errorBorder: outline(XColors.error),
      focusedErrorBorder: outline(XColors.warning, 1.5),
    );
  }
}
