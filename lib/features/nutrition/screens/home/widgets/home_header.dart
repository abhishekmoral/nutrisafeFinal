import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../family/bindings/family_binding.dart';
import '../../../../family/controllers/notifications_controller.dart';
import '../../../../family/screens/family/family.dart';
import '../../../../family/screens/notifications/notifications.dart';
import '../../../../personalization/controllers/user_controller.dart';
import '../../../../../utils/localization/translations.dart';

class XHomeHeader extends StatelessWidget {
  const XHomeHeader({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning'.tr;
    if (hour < 17) return 'Good afternoon'.tr;
    return 'Good evening'.tr;
  }

  @override
  Widget build(BuildContext context) {
    final controller = UserController.instance;
    final notifications = Get.put(NotificationsController());
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    XHelperFunctions.getFormattedDate(DateTime.now(), format: 'EEEE, d MMM'),
                    style: textTheme.labelMedium,
                  ),
                  Obx(
                    () => Text(
                      '$_greeting, ${controller.user.value.firstName}',
                      style: textTheme.headlineMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            /// Notifications bell with unread count
            Obx(
              () => IconButton(
                tooltip: notifications.unread.value == 0
                    ? 'Notifications'.tr
                    : 'Notifications, {value} unread'.trf({'value': notifications.unread.value}),
                onPressed: () async {
                  await Get.to(() => const NotificationsScreen());
                  notifications.refreshCount();
                },
                icon: Badge(
                  isLabelVisible: notifications.unread.value > 0,
                  label: Text('${notifications.unread.value}'),
                  child: const Icon(Iconsax.notification),
                ),
              ),
            ),
          ],
        ),

        /// Family invitation banner
        Obx(
          () => notifications.pendingInvitations.value == 0
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: XSizes.spaceBtwItems),
                  child: InkWell(
                    onTap: () async {
                      await Get.to(() => const FamilyScreen(), binding: FamilyBinding());
                      notifications.refreshCount();
                    },
                    borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
                    child: XRoundedContainer(
                      backgroundColor: XColors.primaryBackground,
                      child: Row(
                        children: [
                          const Icon(Iconsax.people, color: XColors.primary),
                          const SizedBox(width: XSizes.sm),
                          Expanded(
                            child: Text(
                              notifications.pendingInvitations.value == 1
                                  ? 'You have a family invitation'.tr
                                  : 'You have {value} family invitations'.trf({'value': notifications.pendingInvitations.value}),
                              style: textTheme.titleMedium!.apply(color: XColors.textPrimary),
                            ),
                          ),
                          const Icon(Iconsax.arrow_right_3, color: XColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
