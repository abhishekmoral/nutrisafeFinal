import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/sizes.dart';
import '../widgets/add_member_option_card.dart';
import 'add_existing_account.dart';
import 'add_manually.dart';

/// -- Add Family Member: exactly two ways.
class AddMemberScreen extends StatelessWidget {
  const AddMemberScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Add Family Member'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        children: [
          Text('Choose how you want to add a family member to NutriSafe.'.tr, style: textTheme.bodyMedium),
          const SizedBox(height: XSizes.spaceBtwSections),

          /// 01. Existing account
          XAddMemberOptionCard(
            number: '01',
            icon: Iconsax.user_tick,
            title: 'Add Existing Account'.tr,
            description: 'Connect a family member who already has a NutriSafe account.'.tr,
            note: 'Using their unique NutriSafe ID'.tr,
            buttonLabel: 'Find Member'.tr,
            onPressed: () => Get.to(() => const AddExistingAccountScreen()),
          ),
          const SizedBox(height: XSizes.spaceBtwItems),

          /// 02. Managed profile
          XAddMemberOptionCard(
            number: '02',
            icon: Iconsax.profile_add,
            title: 'Add Manually'.tr,
            description: 'Create a profile for someone who does not have a NutriSafe account.'.tr,
            note: 'No separate account or device required'.tr,
            buttonLabel: 'Create Member Profile'.tr,
            onPressed: () => Get.to(() => const ManagedProfileFormScreen()),
          ),
        ],
      ),
    );
  }
}
