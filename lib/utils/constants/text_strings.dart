import 'package:get/get.dart';

/// -- Shared texts in the app language (the English text is the translation key).
class XTexts {
  // -- Global
  static const String appName = 'NutriSafe';
  static String get xContinue => 'Continue'.tr;
  static String get xSkip => 'Skip for now'.tr;
  static String get xSave => 'Save'.tr;
  static String get xCancel => 'Cancel'.tr;
  static String get xDone => 'Done'.tr;
  static String get xSubmit => 'Submit'.tr;

  // -- Authentication
  static String get loginTitle => 'Welcome back,'.tr;
  static String get loginSubTitle => 'Track your food, understand your health, care for your family.'.tr;
  static String get xEmail => 'E-Mail'.tr;
  static String get xPassword => 'Password'.tr;
  static String get xFullName => 'Full Name'.tr;
  static String get xForgetPassword => 'Forget Password?'.tr;
  static String get xSignIn => 'Sign In'.tr;
  static String get xCreateAccount => 'Create Account'.tr;
  static String get xOrSignInWith => 'or sign in with'.tr;
  static String get xOrSignUpWith => 'or sign up with'.tr;
  static String get signupTitle => "Let's create your account".tr;
  static String get xIAgreeTo => 'I agree to the Privacy Policy and Terms of use'.tr;
  static String get confirmEmail => 'Verify your email address!'.tr;
  static String get confirmEmailSubTitle => 'We sent a verification link to your email. Open it to activate your account, then continue.'.tr;
  static String get xResendEmail => 'Resend Email'.tr;
  static String get forgetPasswordTitle => 'Forget password'.tr;
  static String get forgetPasswordSubTitle => "Enter your email and we will send you a password reset link.".tr;
  static String get resetPasswordTitle => 'Password Reset Email Sent'.tr;
  static String get resetPasswordSubTitle => 'Open the link in your email to choose a new password.'.tr;

  // -- Medical safety
  static String get medicalDisclaimer => (
        'NutriSafe gives general, educational nutrition information. It does not diagnose, '
        'prescribe or replace a doctor. If symptoms are severe, persist or worry you, please '
        'see a medical professional.'
      ).tr;
  static String get allergyDisclaimer => (
        'Allergen checks are based on available label data and may be incomplete. '
        'They cannot guarantee that a food is safe for you.'
      ).tr;
  static String get estimateNote => 'Nutrition values are estimates unless marked verified.'.tr;

  // -- Medical reports
  static String get reportAiConsentTitle => 'Let AI read your medical reports?'.tr;
  static String get reportAiConsentBody => (
        'To copy the values and explain them, the report file is sent to the AI service we use '
        "(Anthropic's Claude). This is separate from the other AI permissions. Your reports stay "
        'private and are never shared with family. You can turn this off any time.'
      ).tr;
  static String get reportReviewIntro => (
        'Check every value against your report. The AI copies what is printed, but it can misread '
        'a blurred or handwritten value. Tap a result to correct it, or add a test it missed.'
      ).tr;
  static String get reportDisclaimer => (
        'This explanation is general information written by AI from the values on your report. '
        'It is not a diagnosis. A value outside the laboratory range does not by itself mean you '
        'have a condition. Please discuss your results with a doctor.'
      ).tr;
  static String get reportCriticalNotice => (
        'At least one value on this report is in a range that laboratories usually report to a '
        'doctor straight away. Please contact a doctor or go to a hospital today, and take this '
        'report with you. If you feel very unwell, call 112.'
      ).tr;
}
