import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../controllers/family_controller.dart';
import '../../models/family_invitation_model.dart';
import '../add_member/add_member.dart';
import '../member_details/connected_member_details.dart';
import '../member_details/managed_profile_details.dart';
import '../widgets/member_card.dart';
import '../widgets/member_type_badge.dart';
import '../../../../utils/localization/translations.dart';

/// -- My Family: connected accounts, managed profiles and invitations.
/// Open with: Get.to(() => const FamilyScreen(), binding: FamilyBinding())
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  Future<String?> _askFamilyName(BuildContext context) async {
    final field = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create a family'.tr),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: field,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a family name.'.tr : null,
            decoration: InputDecoration(labelText: 'Family name'.tr, hintText: 'e.g. Sharma Family'.tr, counterText: ''),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, field.text.trim());
            },
            child: Text('Create'.tr),
          ),
        ],
      ),
    );
    return name;
  }

  Future<bool> _confirm(BuildContext context, String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = FamilyController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Family'.tr)),
      floatingActionButton: Obx(
        () => controller.hasFamily && controller.isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => Get.to(() => const AddMemberScreen()),
                icon: const Icon(Iconsax.user_add),
                label: Text('Add Member'.tr),
              )
            : const SizedBox.shrink(),
      ),
      body: Obx(() {
        if (controller.loading.value) return const Center(child: CircularProgressIndicator());

        /// Error with retry
        if (controller.loadError.value != null && !controller.hasFamily) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(XSizes.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.wifi_square, size: 48, color: XColors.darkGrey),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  Text(controller.loadError.value!, textAlign: TextAlign.center),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  OutlinedButton(onPressed: controller.load, child: Text('Try again'.tr)),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// -- Invitations I received
              if (controller.receivedInvitations.isNotEmpty) ...[
                XSectionHeading(title: 'Invitations for you'.tr, showActionButton: false),
                for (final invitation in controller.receivedInvitations)
                  _ReceivedInvitationCard(
                    invitation: invitation,
                    inFamily: controller.hasFamily,
                    busy: controller.working.value,
                    onAccept: () => controller.respondToInvitation(invitation, accept: true),
                    onDecline: () => controller.respondToInvitation(invitation, accept: false),
                  ),
                const SizedBox(height: XSizes.spaceBtwSections),
              ],

              /// -- No family yet
              if (!controller.hasFamily) ...[
                const Icon(Iconsax.people, size: 56, color: XColors.primary),
                const SizedBox(height: XSizes.spaceBtwItems),
                Text('You are not in a family yet'.tr, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: XSizes.sm),
                Text(
                  'Create a family to add members, or accept an invitation from a family admin. Joining a family does not share your diary or reports; you choose what to share.'.tr,
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: XSizes.spaceBtwSections),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: controller.working.value
                        ? null
                        : () async {
                            final name = await _askFamilyName(context);
                            if (name != null) controller.createFamily(name);
                          },
                    child: Text('Create a family'.tr),
                  ),
                ),
              ]
              /// -- My family
              else ...[
                Text(controller.familyName, style: textTheme.headlineMedium),
                Text(
                  [
                    controller.memberCount == 1
                        ? '1 member'.tr
                        : '{count} members'.trf({'count': controller.memberCount}),
                    if (controller.isAdmin) 'You are the Family Admin'.tr,
                  ].join(' · '),
                  style: textTheme.labelMedium,
                ),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Connected accounts
                Text('CONNECTED ACCOUNTS'.tr, style: textTheme.labelLarge),
                for (final member in controller.members)
                  XMemberCard(
                    initial: member.initial,
                    title: member.displayName,
                    subtitle: 'NutriSafe Account · {nutrisafeId}'.trf({'nutrisafeId': member.nutrisafeId ?? ''}),
                    badges: [
                      if (member.userId == controller.myId) MemberBadge.you,
                      member.isAdmin ? MemberBadge.admin : MemberBadge.connected,
                    ],
                    onTap: () => Get.to(() => ConnectedMemberDetailsScreen(member: member)),
                  ),
                const SizedBox(height: XSizes.spaceBtwItems),

                /// Managed profiles
                Text('MANAGED PROFILES'.tr, style: textTheme.labelLarge),
                if (controller.managedProfiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: XSizes.sm),
                    child: Text(
                      controller.isAdmin
                          ? 'No managed profiles. Use "Add Member" to add a child or an elder who has no account.'.tr
                          : 'No managed profiles.'.tr,
                      style: textTheme.labelMedium,
                    ),
                  ),
                for (final profile in controller.managedProfiles)
                  XMemberCard(
                    initial: profile.initial,
                    title: profile.fullName,
                    subtitle: [
                      'Managed Profile'.tr,
                      if (profile.relationshipLabel != null) profile.relationshipLabel!,
                      if (profile.isGuardian) 'You are guardian'.tr else if (profile.canCare) 'You are caregiver'.tr,
                    ].join(' · '),
                    badges: const [MemberBadge.managed],
                    trailing: profile.canCare ? null : const Icon(Iconsax.lock_1, color: XColors.darkGrey),
                    onTap: () => Get.to(() => ManagedProfileDetailsScreen(profileId: profile.id, name: profile.fullName)),
                  ),

                /// Invitations I sent (admin)
                if (controller.isAdmin && controller.sentInvitations.isNotEmpty) ...[
                  const SizedBox(height: XSizes.spaceBtwSections),
                  Text('INVITATIONS SENT'.tr, style: textTheme.labelLarge),
                  for (final invitation in controller.sentInvitations)
                    _SentInvitationTile(
                      invitation: invitation,
                      onCancel: () async {
                        final ok = await _confirm(
                          context,
                          'Cancel invitation?'.tr,
                          '{inviteeName} will no longer be able to accept it.'.trf({'inviteeName': invitation.inviteeName}),
                          'Cancel invitation'.tr,
                        );
                        if (ok) controller.revokeInvitation(invitation);
                      },
                    ),
                ],

                /// Leave
                const SizedBox(height: XSizes.spaceBtwSections),
                OutlinedButton.icon(
                  onPressed: controller.working.value
                      ? null
                      : () async {
                          final ok = await _confirm(
                            context,
                            'Leave {familyName}?'.trf({'familyName': controller.familyName}),
                            'Everything you share with this family stops. Your own account and records stay with you. If you are the only guardian of a managed profile, make someone else its guardian first.'.tr,
                            'Leave'.tr,
                          );
                          if (ok) controller.leaveFamily();
                        },
                  icon: const Icon(Iconsax.logout),
                  label: Text('Leave family'.tr),
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        );
      }),
    );
  }
}

class _ReceivedInvitationCard extends StatelessWidget {
  const _ReceivedInvitationCard({
    required this.invitation,
    required this.inFamily,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final FamilyInvitationModel invitation;
  final bool inFamily;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return XRoundedContainer(
      margin: const EdgeInsets.only(top: XSizes.sm),
      showBorder: true,
      borderColor: XColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(invitation.familyName ?? 'A family'.tr, style: textTheme.titleLarge),
          Text(
            '{invitedByName} invited you · expires {date}'.trf({'invitedByName': invitation.invitedByName, 'date': XHelperFunctions.getFormattedDate(invitation.expiresAt)}),
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: XSizes.sm),
          Text(
            inFamily
                ? 'You are already in a family. Leave it before accepting this invitation.'.tr
                : 'Joining only shows your name and NutriSafe ID to the family. You decide later what to share.'.tr,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: XSizes.sm),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: busy ? null : onDecline, child: Text('Decline'.tr))),
              const SizedBox(width: XSizes.spaceBtwItems),
              Expanded(
                child: ElevatedButton(onPressed: busy || inFamily ? null : onAccept, child: Text('Accept'.tr)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentInvitationTile extends StatelessWidget {
  const _SentInvitationTile({required this.invitation, required this.onCancel});

  final FamilyInvitationModel invitation;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final color = switch (invitation.status) {
      'pending' => XColors.warning,
      'accepted' => XColors.success,
      'rejected' || 'revoked' => XColors.error,
      _ => XColors.darkGrey,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(invitation.inviteeName ?? 'NutriSafe user'.tr),
      subtitle: Text(
        '{nutrisafeId} · sent {date}'.trf({
          'nutrisafeId': invitation.inviteeNutrisafeId ?? '',
          'date': XHelperFunctions.getFormattedDate(invitation.createdAt),
        }),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(invitation.statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (invitation.isPending)
            IconButton(
              tooltip: 'Cancel invitation to {inviteeName}'.trf({'inviteeName': invitation.inviteeName}),
              onPressed: onCancel,
              icon: const Icon(Iconsax.close_circle),
            ),
        ],
      ),
    );
  }
}
