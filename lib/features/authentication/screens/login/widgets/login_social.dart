import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../common/widgets/login_signup/form_divider.dart';
import '../../../../../common/widgets/login_signup/social_buttons.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../controllers/login_controller.dart';

class LoginSocial extends StatelessWidget {
  const LoginSocial({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());
    return Column(
      children: [
        /// Divider
        XFormDivider(dividerText: XTexts.xOrSignInWith),
        const SizedBox(height: XSizes.spaceBtwItems),

        /// Google Button
        XSocialButtons(onGooglePressed: controller.googleSignIn),
      ],
    );
  }
}
