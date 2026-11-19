import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class XHelperFunctions {
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Size screenSize() {
    return MediaQuery.of(Get.context!).size;
  }

  static double screenHeight() {
    return MediaQuery.of(Get.context!).size.height;
  }

  static double screenWidth() {
    return MediaQuery.of(Get.context!).size.width;
  }

  static String getFormattedDate(DateTime date, {String format = 'dd MMM yyyy'}) {
    return DateFormat(format).format(date);
  }

  /// Date in `yyyy-MM-dd` (the user's local calendar day) for database columns.
  static String toDbDate(DateTime date) {
    return DateFormat('yyyy-MM-dd', 'en_US').format(date); // always Latin digits, whatever the app language
  }

  /// Friendly day label: Today / Yesterday / 12 Nov 2026.
  static String dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today'.tr;
    if (diff == 1) return 'Yesterday'.tr;
    return getFormattedDate(date);
  }

  static int calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  /// 12.0 -> "12", 12.345 -> "12.3". Unknown values show as "–", never as 0.
  static String formatNumber(num? value, {int decimals = 1}) {
    if (value == null) return '–';
    final fixed = value.toStringAsFixed(decimals);
    return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
  }

  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}
