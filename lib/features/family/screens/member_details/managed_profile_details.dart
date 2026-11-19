import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/popups/loaders.dart';
import '../../../nutrition/models/nutrition_values.dart';
import '../../../personalization/controllers/profile_setup_controller.dart';
import '../../controllers/managed_profile_controller.dart';
import '../../models/diary_subject.dart';
import '../../models/family_member_model.dart';
import '../../models/managed_profile_model.dart';
import '../add_member/add_manually.dart';
import '../member_diary/member_diary.dart';
import '../widgets/member_type_badge.dart';
import 'widgets/nutrition_today_card.dart';
import '../../../../utils/localization/translations.dart';

/// -- A managed profile: details, allergies, nutrition, food diary, guardians and caregivers.
class ManagedProfileDetailsScreen extends StatelessWidget {
  const ManagedProfileDetailsScreen({super.key, required this.profileId, required this.name});

  final String profileId;
  final String name;

  Future<void> _addCarer(BuildContext context, ManagedProfileController controller) async {
    final candidates = controller.possibleCarers;
    if (candidates.isEmpty) {
      XLoaders.warningSnackBar(
        title: 'No one to add'.tr,
        message: 'Every family member with an account already looks after this profile.'.tr,
      );
      return;
    }
    FamilyMemberModel? chosen = candidates.first;
    String role = 'caregiver';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add a guardian or caregiver'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<FamilyMemberModel>(
                initialValue: chosen,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Family member'.tr),
                items: [for (final m in candidates) DropdownMenuItem(value: m, child: Text(m.displayName))],
                onChanged: (v) => setState(() => chosen = v),
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              RadioGroup<String>(
                groupValue: role,
                onChanged: (v) => setState(() => role = v ?? role),
                child: Column(
                  children: [
                    RadioListTile(
                      value: 'caregiver',
                      title: Text('Caregiver'.tr),
                      subtitle: Text('Sees the profile and keeps its food diary'.tr),
                    ),
                    RadioListTile(
                      value: 'guardian',
                      title: Text('Guardian'.tr),
                      subtitle: Text('Also edits the profile, allergies and carers'.tr),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Add'.tr)),
          ],
        ),
      ),
    );
    if (ok == true && chosen != null) await controller.addCarer(chosen!, role);
  }

  Future<bool> _confirm(BuildContext context, String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action, style: const TextStyle(color: XColors.error)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ManagedProfileController(profileId: profileId), tag: profileId);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: XAppBar(
        showBackArrow: true,
        title: Text(name, overflow: TextOverflow.ellipsis),
        actions: [
          Obx(
            () => controller.isGuardian
                ? IconButton(
                    tooltip: 'Edit profile'.tr,
                    onPressed: () async {
                      final saved = await Get.to<bool>(
                        () => ManagedProfileFormScreen(
                          existing: controller.profile.value,
                          existingAllergies: controller.allergies.toList(),
                        ),
                      );
                      if (saved == true) controller.load();
                    },
                    icon: const Icon(Iconsax.edit),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) return const Center(child: CircularProgressIndicator());

        /// Family member without a role: name only.
        if (controller.noAccess.value) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(XSizes.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.lock_1, size: 48, color: XColors.darkGrey),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  Text(name, style: textTheme.headlineSmall),
                  const SizedBox(height: XSizes.sm),
                  Text(
                    'Only the guardians and caregivers of this profile can see its details. Ask a guardian to add you.'.tr,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final p = controller.profile.value!;
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
                      p.initial,
                      style: const TextStyle(fontSize: 22, color: XColors.primaryDark, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: XSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.fullName, style: textTheme.headlineSmall),
                        Row(
                          children: [
                            Flexible(child: Text(p.managedId, style: textTheme.labelLarge)),
                            IconButton(
                              tooltip: 'Copy managed profile ID'.tr,
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: p.managedId));
                                XLoaders.successSnackBar(title: 'Profile ID copied'.tr);
                              },
                              icon: const Icon(Iconsax.copy, size: XSizes.iconSm),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: XSizes.xs,
                          children: [
                            XMemberTypeBadge(badge: MemberBadge.managed, label: 'Managed Profile'.tr),
                            XMemberTypeBadge(
                              badge: MemberBadge.connected,
                              label: p.isGuardian ? 'You are guardian'.tr : 'You are caregiver'.tr,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              for (final (label, value) in <(String, String?)>[
                ('Relationship'.tr, p.relationshipLabel),
                ('Date of birth'.tr, p.dateOfBirth == null ? null : '${XHelperFunctions.getFormattedDate(p.dateOfBirth!)} (${p.age} years)'),
                ('Gender'.tr, ProfileSetupController.genders[p.gender]?.tr),
                ('Diet'.tr, ProfileSetupController.dietaryPreferences[p.dietaryPreference]?.tr),
                ('Notes'.tr, p.notes),
              ])
                if (value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: XSizes.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 110, child: Text(label, style: textTheme.labelLarge)),
                        Expanded(child: Text(value, style: textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Allergies
              XSectionHeading(title: 'Allergies'.tr, showActionButton: false),
              if (controller.allergies.isEmpty)
                Text('None recorded'.tr, style: textTheme.labelMedium)
              else
                Wrap(
                  spacing: XSizes.xs,
                  runSpacing: XSizes.xs,
                  children: [
                    for (final a in controller.allergies)
                      Chip(
                        avatar: const Icon(Iconsax.warning_2, size: XSizes.iconSm, color: XColors.error),
                        label: Text(a),
                      ),
                  ],
                ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Nutrition dashboard + food diary
              XSectionHeading(title: 'Nutrition'.tr, showActionButton: false),
              XNutritionTodayCard(
                values: controller.today.value ?? NutritionValues.empty,
                footer: 'Food logged on {value} of the last 7 days.'.trf({'value': controller.loggedDaysThisWeek.value}),
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Get.to(
                      () => MemberDiaryScreen(subject: DiarySubject.managed(name: p.fullName, childId: p.id)),
                    );
                    controller.load();
                  },
                  icon: const Icon(Iconsax.book_1),
                  label: Text('Open {fullName}\'s food diary'.trf({'fullName': p.fullName})),
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Guardians and caregivers
              XSectionHeading(
                title: 'Guardians & caregivers'.tr,
                showActionButton: p.isGuardian,
                buttonTitle: 'Add'.tr,
                onPressed: () => _addCarer(context, controller),
              ),
              for (final carer in controller.carers)
                _CarerTile(
                  carer: carer,
                  isMe: carer.userId == controller.myId,
                  canManage: p.isGuardian,
                  onRoleChanged: (role) => controller.setCarerRole(carer, role),
                  onRemove: () async {
                    final me = carer.userId == controller.myId;
                    final ok = await _confirm(
                      context,
                      me ? 'Stop looking after {fullName}?'.trf({'fullName': p.fullName}) : 'Remove {displayName}?'.trf({'displayName': carer.displayName}),
                      me
                          ? 'You will no longer see this profile. A profile always keeps at least one guardian.'.tr
                          : '{displayName} will no longer see this profile.'.trf({'displayName': carer.displayName}),
                      'Remove'.tr,
                    );
                    if (ok) controller.removeCarer(carer);
                  },
                ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// -- Delete (guardians)
              if (p.isGuardian)
                OutlinedButton.icon(
                  onPressed: controller.working.value
                      ? null
                      : () async {
                          final ok = await _confirm(
                            context,
                            'Delete {fullName}?'.trf({'fullName': p.fullName}),
                            'The profile, its food diary, allergies and all other records are permanently deleted for everyone. This cannot be undone.'.tr,
                            'Delete'.tr,
                          );
                          if (ok) controller.deleteProfile();
                        },
                  icon: const Icon(Iconsax.trash, color: XColors.error),
                  label: Text('Delete member profile'.tr),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _CarerTile extends StatelessWidget {
  const _CarerTile({
    required this.carer,
    required this.isMe,
    required this.canManage,
    required this.onRoleChanged,
    required this.onRemove,
  });

  final CarerModel carer;
  final bool isMe;
  final bool canManage;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: XColors.primaryBackground,
        child: Text(carer.displayName[0].toUpperCase(), style: const TextStyle(color: XColors.primaryDark)),
      ),
      title: Text(isMe ? '{displayName} (you)'.trf({'displayName': carer.displayName}) : carer.displayName),
      subtitle: Text('${carer.role == 'guardian' ? 'Guardian'.tr : 'Caregiver'.tr} · ${carer.nutrisafeId ?? ''}'),
      trailing: (canManage || isMe)
          ? PopupMenuButton<String>(
              tooltip: 'Options for {displayName}'.trf({'displayName': carer.displayName}),
              onSelected: (value) => value == 'remove' ? onRemove() : onRoleChanged(value),
              itemBuilder: (context) => [
                if (canManage && carer.role != 'guardian')
                  PopupMenuItem(value: 'guardian', child: Text('Make guardian'.tr)),
                if (canManage && carer.role == 'guardian')
                  PopupMenuItem(value: 'caregiver', child: Text('Make caregiver'.tr)),
                PopupMenuItem(value: 'remove', child: Text(isMe ? 'Stop looking after'.tr : 'Remove'.tr)),
              ],
            )
          : null,
    );
  }
}
