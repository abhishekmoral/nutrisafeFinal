import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../data/repositories/authentication/authentication_repository.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/exceptions/exception_handler.dart';
import '../../../../utils/popups/loaders.dart';
import '../../../../utils/validators/validation.dart';

/// -- Shown when the user opens the password reset link from the email.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthenticationRepository.instance.updatePassword(_password.text);
      XLoaders.successSnackBar(title: 'Password updated'.tr);
      await AuthenticationRepository.instance.screenRedirect();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not update'.tr, message: XExceptionHandler.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: Text('Choose a new password'.tr)),
      body: Padding(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              /// New password
              TextFormField(
                controller: _password,
                obscureText: true,
                validator: XValidator.validatePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'New password'.tr,
                  prefixIcon: Icon(Iconsax.password_check),
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text('Save password'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
