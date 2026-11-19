import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../constants/colors.dart';

class XLoaders {
  static void successSnackBar({required String title, String message = ''}) {
    _show(title, message, XColors.success, Iconsax.tick_circle);
  }

  static void warningSnackBar({required String title, String message = ''}) {
    _show(title, message, XColors.warning, Iconsax.warning_2);
  }

  static void errorSnackBar({required String title, String message = ''}) {
    _show(title, message, XColors.error, Iconsax.close_circle);
  }

  static void _show(String title, String message, Color color, IconData icon) {
    Get.snackbar(
      title.tr,
      message.tr,
      isDismissible: true,
      shouldIconPulse: false,
      colorText: Colors.white,
      backgroundColor: color,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(16),
      icon: Icon(icon, color: Colors.white),
    );
  }

  /// Full screen blocking loader
  static void openLoadingDialog() {
    Get.dialog(
      const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      barrierDismissible: false,
    );
  }

  static void stopLoading() {
    if (Get.isDialogOpen ?? false) Get.back();
  }
}
