import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../features/personalization/controllers/user_controller.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/enums.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/localization/language_helper.dart';
import '../../../utils/popups/loaders.dart';

/// -- Pick the app language. Every screen switches at once; signed-in users also keep it in their account.
class XLanguagePicker {
  XLanguagePicker._();

  static Future<void> show(BuildContext context, {bool saveToAccount = false}) async {
    final current = XLanguageHelper.current;
    final picked = await showModalBottomSheet<AppLanguage>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: XSizes.md),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: XSizes.defaultSpace),
                child: Text('App language'.tr, style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: XSizes.sm),
              for (final language in AppLanguage.values)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: XSizes.defaultSpace),
                  title: Text(language.label),
                  selected: language == current,
                  trailing: language == current ? const Icon(Iconsax.tick_circle, color: XColors.primary) : null,
                  onTap: () => Navigator.pop(context, language),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == current) return;
    try {
      saveToAccount ? await UserController.instance.setLanguage(picked) : await XLanguageHelper.apply(picked);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save'.tr, message: XExceptionHandler.message(e));
    }
  }
}

/// A small "language" button for screens shown before sign-in.
class XLanguageButton extends StatelessWidget {
  const XLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => XLanguagePicker.show(context),
      icon: const Icon(Iconsax.language_square),
      label: Text(XLanguageHelper.current.label),
    );
  }
}
