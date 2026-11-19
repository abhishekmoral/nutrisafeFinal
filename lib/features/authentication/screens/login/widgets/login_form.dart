import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/validators/validation.dart';
import '../../../controllers/login_controller.dart';
import '../../password_configuration/forget_password.dart';
import '../../signup/signup.dart';

class LoginForm extends StatelessWidget {
  const LoginForm({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());
    return Form(
      key: controller.loginFormKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: XSizes.lg),
        child: Column(
          children: [
            /// Email
            TextFormField(
              controller: controller.email,
              validator: XValidator.validateEmail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                prefixIcon: Icon(Iconsax.direct_right),
                labelText: XTexts.xEmail,
              ),
            ),
            const SizedBox(height: XSizes.spaceBtwInputFields),

            /// Password
            Obx(
              () => TextFormField(
                controller: controller.password,
                validator: (value) => XValidator.validateEmptyText('Password'.tr, value),
                obscureText: controller.hidePassword.value,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => controller.emailAndPasswordSignIn(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Iconsax.password_check),
                  labelText: XTexts.xPassword,
                  suffixIcon: IconButton(
                    tooltip: controller.hidePassword.value ? 'Show password'.tr : 'Hide password'.tr,
                    onPressed: () => controller.hidePassword.toggle(),
                    icon: Icon(controller.hidePassword.value ? Iconsax.eye_slash : Iconsax.eye),
                  ),
                ),
              ),
            ),

            /// Forget Password
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Get.to(() => const ForgetPasswordScreen()),
                child: Text(XTexts.xForgetPassword),
              ),
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Sign In Button
            SizedBox(
              width: double.infinity,
              child: Obx(
                () => ElevatedButton(
                  onPressed: controller.loading.value ? null : controller.emailAndPasswordSignIn,
                  child: Text(controller.loading.value ? 'Signing in...'.tr : XTexts.xSignIn),
                ),
              ),
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Create Account Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Get.to(() => const SignupScreen()),
                child: Text(XTexts.xCreateAccount),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
