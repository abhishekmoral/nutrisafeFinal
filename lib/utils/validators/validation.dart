import 'package:get/get.dart';

import '../../utils/localization/translations.dart';
/// VALIDATION CLASS
class XValidator {
  /// Empty Text Validation
  static String? validateEmptyText(String? fieldName, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '{fieldName} is required.'.trf({'fieldName': fieldName});
    }
    return null;
  }

  /// Email Validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.'.tr;
    }
    final emailRegExp = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Invalid email address.'.tr;
    }
    return null;
  }

  /// Password Validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.'.tr;
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.'.tr;
    }
    if (!value.contains(RegExp(r'[A-Za-z]'))) {
      return 'Password must contain at least one letter.'.tr;
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number.'.tr;
    }
    return null;
  }

  /// Positive number (quantity, grams, ml ...)
  static String? validatePositiveNumber(String? fieldName, String? value) {
    if (value == null || value.trim().isEmpty) {
      return '{fieldName} is required.'.trf({'fieldName': fieldName});
    }
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) {
      return 'Enter a valid {fieldName}.'.trf({'fieldName': fieldName});
    }
    return null;
  }

  /// Optional number inside a range (height, weight, nutrients ...)
  static String? validateOptionalRange(String fieldName, String? value, double min, double max) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    if (number == null || number < min || number > max) {
      return '{fieldName} must be between {value} and {value2}.'.trf({'fieldName': fieldName, 'value': min.toStringAsFixed(0), 'value2': max.toStringAsFixed(0)});
    }
    return null;
  }
}
