import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../bindings/family_binding.dart';
import '../../controllers/notifications_controller.dart';
import '../family/family.dart';

/// -- In-app notifications. They never contain health or nutrition details.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = NotificationsController.instance;
    controller.open();
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Notifications'.tr)),
      body: Obx(() {
        if (controller.loading.value && controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.items.isEmpty) {
          return Center(child: Text('No notifications yet.'.tr));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(XSizes.defaultSpace),
          itemCount: controller.items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final n = controller.items[index];
            final created = DateTime.parse(n['created_at'] as String).toLocal();
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Iconsax.notification, color: n['read_at'] == null ? XColors.primary : XColors.darkGrey),
              title: Text((n['title'] as String).tr),
              subtitle: Text('${(n['body'] as String? ?? '').tr}\n${XHelperFunctions.dayLabel(created)}'),
              isThreeLine: true,
              onTap: () => Get.off(() => const FamilyScreen(), binding: FamilyBinding()),
            );
          },
        );
      }),
    );
  }
}
