import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/login_signup/form_divider.dart';
import '../../../../common/widgets/login_signup/social_buttons.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/validators/validation.dart';
import '../../controllers/login_controller.dart';
import '../../controllers/signup_controller.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SignupController());
    return Scaffold(
      appBar: const XAppBar(showBackArrow: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(XSizes.defaultSpace),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Title
              Text(XTexts.signupTitle, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Form
              Form(
                key: controller.signupFormKey,
                child: Column(
                  children: [
                    /// Full Name
                    TextFormField(
                      controller: controller.fullName,
                      validator: (value) => XValidator.validateEmptyText('Full name'.tr, value),
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: XTexts.xFullName,
                        prefixIcon: Icon(Iconsax.user),
                      ),
                    ),
                    const SizedBox(height: XSizes.spaceBtwInputFields),

                    /// Email
                    TextFormField(
                      controller: controller.email,
                      validator: XValidator.validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: XTexts.xEmail,
                        prefixIcon: Icon(Iconsax.direct),
                      ),
                    ),
                    const SizedBox(height: XSizes.spaceBtwInputFields),

                    /// Password
                    Obx(
                      () => TextFormField(
                        controller: controller.password,
                        validator: XValidator.validatePassword,
                        obscureText: controller.hidePassword.value,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: XTexts.xPassword,
                          prefixIcon: const Icon(Iconsax.password_check),
                          suffixIcon: IconButton(
                            tooltip: controller.hidePassword.value
                                ? 'Show password'.tr
                                : 'Hide password'.tr,
                            onPressed: () => controller.hidePassword.toggle(),
                            icon: Icon(
                              controller.hidePassword.value ? Iconsax.eye_slash : Iconsax.eye,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: XSizes.spaceBtwItems),

                    /// Terms & Conditions Checkbox
                    Row(
                      children: [
                        Obx(
                          () => Checkbox(
                            value: controller.privacyPolicy.value,
                            onChanged: (value) => controller.privacyPolicy.value = value ?? false,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            XTexts.xIAgreeTo,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: XSizes.spaceBtwItems),

                    /// Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      child: Obx(
                        () => ElevatedButton(
                          onPressed: controller.loading.value ? null : controller.signup,
                          child: Text(
                            controller.loading.value ? 'Creating account...'.tr : XTexts.xCreateAccount,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Divider
              XFormDivider(dividerText: XTexts.xOrSignUpWith),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Social Button
              XSocialButtons(onGooglePressed: Get.put(LoginController()).googleSignIn),
            ],
          ),
        ),
      ),
    );
  }
}
