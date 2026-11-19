import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/popups/loaders.dart';
import '../../../personalization/controllers/profile_setup_controller.dart';
import '../../controllers/family_controller.dart';
import '../../controllers/member_details_controller.dart';
import '../../models/family_member_model.dart';
import '../member_diary/member_diary.dart';
import '../widgets/member_type_badge.dart';
import 'widgets/nutrition_today_card.dart';
import '../../../../utils/localization/translations.dart';

/// -- A connected account: who they are, what I share with them, what they share with me.
class ConnectedMemberDetailsScreen extends StatelessWidget {
  const ConnectedMemberDetailsScreen({super.key, required this.member});

  final FamilyMemberModel member;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MemberDetailsController(member: member), tag: member.userId);
    final family = FamilyController.instance;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text(member.displayName, overflow: TextOverflow.ellipsis)),
      body: Obx(() {
        if (controller.loading.value) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// -- Personal details
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: XColors.primaryBackground,
                    child: Text(
                      member.initial,
                      style: const TextStyle(fontSize: 22, color: XColors.primaryDark, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: XSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.displayName, style: textTheme.headlineSmall),
                        Row(
                          children: [
                            Flexible(child: Text(member.nutrisafeId ?? '', style: textTheme.labelLarge)),
                            if (member.nutrisafeId != null)
                              IconButton(
                                tooltip: 'Copy NutriSafe ID'.tr,
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: member.nutrisafeId!));
                                  XLoaders.successSnackBar(title: 'NutriSafe ID copied'.tr);
                                },
                                icon: const Icon(Iconsax.copy, size: XSizes.iconSm),
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: XSizes.xs,
                          children: [
                            XMemberTypeBadge(badge: MemberBadge.connected, label: 'NutriSafe Account'.tr),
                            XMemberTypeBadge(
                              badge: member.isAdmin ? MemberBadge.admin : MemberBadge.connected,
                              label: member.isAdmin ? 'Family Admin'.tr : 'Member'.tr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.sm),
              Text('Joined {date}'.trf({'date': XHelperFunctions.getFormattedDate(member.joinedAt)}), style: textTheme.labelMedium),
              const SizedBox(height: XSizes.spaceBtwSections),

              if (controller.isMe)
                Text(
                  'This is you. Open another member to choose what you share with them.'.tr,
                  style: textTheme.bodyMedium,
                )
              else ...[
                /// -- What they share with me
                XSectionHeading(title: 'Shared with you by {displayName}'.trf({'displayName': member.displayName}), showActionButton: false),
                if (controller.theyShare.isEmpty)
                  Text(
                    '{displayName} has not shared anything with you. Their data stays private until they turn sharing on for you.'.trf({'displayName': member.displayName}),
                    style: textTheme.labelMedium,
                  )
                else ...[
                  Wrap(
                    spacing: XSizes.xs,
                    runSpacing: XSizes.xs,
                    children: [for (final s in controller.theyShare) Chip(label: Text(FamilyScope.label(s)))],
                  ),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  if (controller.sharedProfile.value != null) _SharedProfile(controller: controller),
                  if (controller.theyAllow(FamilyScope.viewAllergies)) ...[
                    const SizedBox(height: XSizes.spaceBtwItems),
                    Text('Allergies'.tr, style: textTheme.titleMedium),
                    Text(
                      controller.sharedAllergies.isEmpty ? 'None recorded'.tr : controller.sharedAllergies.join(', '),
                      style: textTheme.bodyMedium,
                    ),
                  ],
                  if (controller.today.value != null) ...[
                    const SizedBox(height: XSizes.spaceBtwItems),
                    XNutritionTodayCard(values: controller.today.value!),
                  ],
                  if (controller.theyAllow(FamilyScope.viewFoodDiary)) ...[
                    const SizedBox(height: XSizes.spaceBtwItems),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => Get.to(() => MemberDiaryScreen(subject: controller.diarySubject)),
                        icon: const Icon(Iconsax.book_1),
                        label: Text('Open {displayName}\'s food diary'.trf({'displayName': member.displayName})),
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: XSizes.spaceBtwSections),

                /// -- What I share with them
                XSectionHeading(title: 'What you share with {displayName}'.trf({'displayName': member.displayName}), showActionButton: false),
                Text(
                  'Private by default. Medical reports are never shared from here.'.tr,
                  style: textTheme.labelMedium,
                ),
                for (final (scope, label, description) in FamilyScope.all)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(label.tr),
                    subtitle: Text(description.tr),
                    value: controller.iShare.contains(scope),
                    onChanged: controller.saving.value == null ? (v) => controller.setShare(scope, v) : null,
                  ),

                /// -- Admin: remove
                if (family.isAdmin) ...[
                  const SizedBox(height: XSizes.spaceBtwSections),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Remove {displayName}?'.trf({'displayName': member.displayName})),
                          content: Text(
                            'They leave the family and all sharing between you stops. Their own account and records stay with them.'.tr,
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove'.tr)),
                          ],
                        ),
                      );
                      if (ok == true && await family.removeMember(member)) Get.back();
                    },
                    icon: const Icon(Iconsax.user_remove, color: XColors.error),
                    label: Text('Remove from family'.tr),
                  ),
                ],
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _SharedProfile extends StatelessWidget {
  const _SharedProfile({required this.controller});

  final MemberDetailsController controller;

  @override
  Widget build(BuildContext context) {
    final p = controller.sharedProfile.value!;
    final rows = <(String, String)>[
      if (p.age != null) ('Age'.tr, '${p.age} years'),
      if (p.heightCm != null) ('Height'.tr, '${XHelperFunctions.formatNumber(p.heightCm)} cm'),
      if (p.weightKg != null) ('Weight'.tr, '${XHelperFunctions.formatNumber(p.weightKg)} kg'),
      if (p.dietaryPreference != null)
        ('Diet'.tr, (ProfileSetupController.dietaryPreferences[p.dietaryPreference] ?? p.dietaryPreference!).tr),
    ];
    return XRoundedContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile'.tr, style: Theme.of(context).textTheme.titleMedium),
          if (rows.isEmpty) Text('No details filled in.'.tr),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(top: XSizes.xs),
              child: Row(children: [SizedBox(width: 80, child: Text(label)), Expanded(child: Text(value))]),
            ),
        ],
      ),
    );
  }
}
