import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/exceptions/exception_handler.dart';
import '../../../../utils/popups/loaders.dart';
import '../login/login.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key, required this.email});

  final String email;

  Future<void> _resend() async {
    try {
      await AuthenticationRepository.instance.resendVerificationEmail(email);
      XLoaders.successSnackBar(title: 'Email sent'.tr, message: 'Please check your inbox.'.tr);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not send email'.tr, message: XExceptionHandler.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Close'.tr,
            onPressed: () => Get.offAll(() => const LoginScreen()),
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(XSizes.defaultSpace),
          child: Column(
            children: [
              /// Icon
              const Icon(Iconsax.sms_tracking, size: 110, color: XColors.primary),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Title & SubTitle
              Text(
                XTexts.confirmEmail,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              Text(email, style: Theme.of(context).textTheme.labelLarge, textAlign: TextAlign.center),
              const SizedBox(height: XSizes.spaceBtwItems),
              Text(
                XTexts.confirmEmailSubTitle,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.offAll(() => const LoginScreen()),
                  child: Text('I have verified, Sign In'.tr),
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              SizedBox(
                width: double.infinity,
                child: TextButton(onPressed: _resend, child: Text(XTexts.xResendEmail)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
