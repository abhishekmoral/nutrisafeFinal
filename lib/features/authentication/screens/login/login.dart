import 'package:flutter/material.dart';

import '../../../../common/styles/spacing_styles.dart';
import '../../../../common/widgets/language/language_picker.dart';
import '../../../../utils/constants/sizes.dart';
import 'widgets/login_form.dart';
import 'widgets/login_header.dart';
import 'widgets/login_social.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: XSpacingStyle.paddingWithAppBarHeight,
          child: Column(
            children: [
              /// Language (before sign-in)
              Align(alignment: AlignmentDirectional.centerEnd, child: XLanguageButton()),

              /// Logo, Title and SubTitle
              LoginHeader(),
              SizedBox(height: XSizes.spaceBtwItems),

              /// Form
              LoginForm(),
              SizedBox(height: XSizes.spaceBtwItems),

              /// Divider and Social Buttons.
              LoginSocial(),
            ],
          ),
        ),
      ),
    );
  }
}
