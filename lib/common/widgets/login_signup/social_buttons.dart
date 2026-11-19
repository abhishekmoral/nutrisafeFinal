import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../utils/constants/colors.dart';

class XSocialButtons extends StatelessWidget {
  const XSocialButtons({super.key, required this.onGooglePressed});

  final VoidCallback onGooglePressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onGooglePressed,
        icon: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: XColors.googleBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: const Text(
            'G',
            style: TextStyle(fontWeight: FontWeight.bold, color: XColors.googleForegroundColor),
          ),
        ),
        label: Text('Continue with Google'.tr),
      ),
    );
  }
}
