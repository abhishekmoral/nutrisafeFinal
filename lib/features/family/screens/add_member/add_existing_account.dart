import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../controllers/add_member_controller.dart';
import '../../models/family_invitation_model.dart';
import '../../../../utils/localization/translations.dart';

/// -- Method 01: find an existing account by its NutriSafe ID and invite it.
class AddExistingAccountScreen extends StatelessWidget {
  const AddExistingAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddMemberController());
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Add Existing Account'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        children: [
          Text(
            'Enter the family member\'s NutriSafe ID. They can find it on their Profile screen.'.tr,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: XSizes.spaceBtwItems),

          /// ID field
          TextField(
            controller: controller.idField,
            onChanged: controller.onChanged,
            onSubmitted: (_) => controller.find(),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            maxLength: 12,
            decoration: InputDecoration(
              labelText: 'NutriSafe ID'.tr,
              hintText: 'NS-84K92P',
              prefixIcon: Icon(Iconsax.personalcard),
              counterText: '',
            ),
          ),
          const SizedBox(height: XSizes.spaceBtwItems),
          Obx(() {
            final searching = controller.state.value == LookupState.searching;
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: searching ? null : controller.find,
                icon: searching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Iconsax.search_normal),
                label: Text(searching ? 'Finding...'.tr : 'Find Member'.tr),
              ),
            );
          }),
          const SizedBox(height: XSizes.spaceBtwSections),

          /// Result
          Obx(() {
            switch (controller.state.value) {
              case LookupState.idle:
              case LookupState.searching:
                return const SizedBox.shrink();
              case LookupState.notFound:
                return _Message(icon: Iconsax.user_search, text: controller.message.value ?? 'Account not found.'.tr);
              case LookupState.failed:
                return _Message(
                  icon: Iconsax.info_circle,
                  text: controller.message.value ?? 'Something went wrong.'.tr,
                  actionLabel: 'Try again'.tr,
                  onAction: controller.find,
                );
              case LookupState.sent:
                return _Message(
                  icon: Iconsax.tick_circle,
                  color: XColors.success,
                  text: 'Invitation sent to {displayName}. They will see it in NutriSafe and can accept or decline. It expires in 7 days.'.trf({'displayName': controller.result.value?.displayName}),
                  actionLabel: 'Done'.tr,
                  onAction: () => Get.back(),
                );
              case LookupState.found:
              case LookupState.sending:
                return _Preview(controller: controller);
            }
          }),
        ],
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.controller});

  final AddMemberController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final AccountLookupModel account = controller.result.value!;
    final sending = controller.state.value == LookupState.sending;
    final (String? blockedText, bool canInvite) = switch (account.relation) {
      'self' => ('This is your own NutriSafe ID.'.tr, false),
      'member' => ('{displayName} is already in your family.'.trf({'displayName': account.displayName}), false),
      'invited' => ('An invitation to {displayName} is already pending.'.trf({'displayName': account.displayName}), false),
      _ => (null, true),
    };

    return XRoundedContainer(
      showBorder: true,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: XColors.primaryBackground,
            child: Text(
              account.displayName[0].toUpperCase(),
              style: const TextStyle(fontSize: 24, color: XColors.primaryDark, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: XSizes.sm),
          Text(account.displayName, style: textTheme.headlineSmall, textAlign: TextAlign.center),
          Text('NutriSafe Account · {nutrisafeId}'.trf({'nutrisafeId': account.nutrisafeId}), style: textTheme.labelMedium),
          const SizedBox(height: XSizes.spaceBtwItems),
          if (blockedText != null)
            Text(blockedText, style: textTheme.bodyMedium, textAlign: TextAlign.center)
          else ...[
            Text(
              'They will get an invitation and must accept it. Joining does not give you access to their data; they choose what to share.'.tr,
              style: textTheme.labelMedium,
              textAlign: TextAlign.center,
            ),
            if (controller.message.value != null) ...[
              const SizedBox(height: XSizes.sm),
              Text(controller.message.value!, style: textTheme.bodyMedium!.apply(color: XColors.error)),
            ],
            const SizedBox(height: XSizes.spaceBtwItems),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canInvite && !sending ? controller.sendInvitation : null,
                icon: const Icon(Iconsax.send_1),
                label: Text(sending ? 'Sending...'.tr : 'Send Invitation'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.color, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 48, color: color ?? XColors.darkGrey),
        const SizedBox(height: XSizes.spaceBtwItems),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        if (actionLabel != null) ...[
          const SizedBox(height: XSizes.spaceBtwItems),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}
