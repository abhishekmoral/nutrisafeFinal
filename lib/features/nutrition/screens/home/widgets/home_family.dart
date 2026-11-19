import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../common/widgets/texts/section_heading.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../family/bindings/family_binding.dart';
import '../../../../family/controllers/family_controller.dart';
import '../../../../family/screens/add_member/add_member.dart';
import '../../../../family/screens/family/family.dart';
import '../../../../family/screens/member_details/connected_member_details.dart';
import '../../../../family/screens/member_details/managed_profile_details.dart';

/// -- Home: the family members already added (connected accounts and managed profiles).
class XHomeFamily extends StatelessWidget {
  const XHomeFamily({super.key});

  void _openFamily() => Get.to(() => const FamilyScreen(), binding: FamilyBinding());

  @override
  Widget build(BuildContext context) {
    final controller = FamilyController.instance;
    final textTheme = Theme.of(context).textTheme;

    return Obx(() {
      // Nothing to show until the first load finishes, or when it failed (the Family screen explains errors).
      if (controller.loading.value && !controller.hasFamily) return const SizedBox.shrink();
      if (controller.loadError.value != null && !controller.hasFamily) return const SizedBox.shrink();

      /// No family yet: a small invitation to start one
      if (!controller.hasFamily) {
        return Padding(
          padding: const EdgeInsets.only(bottom: XSizes.spaceBtwSections),
          child: InkWell(
            onTap: _openFamily,
            borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
            child: XRoundedContainer(
              showBorder: true,
              child: Row(
                children: [
                  const Icon(Iconsax.people, color: XColors.primary),
                  const SizedBox(width: XSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Add your family'.tr, style: textTheme.titleMedium),
                        Text(
                          'Track food and allergies for the people you care for.'.tr,
                          style: textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Iconsax.arrow_right_3),
                ],
              ),
            ),
          ),
        );
      }

      final others = controller.members.where((m) => m.userId != controller.myId).toList();
      final people = <_Person>[
        for (final m in others)
          _Person(
            name: m.displayName,
            initial: m.initial,
            tag: m.isAdmin ? 'Admin'.tr : 'Connected'.tr,
            managed: false,
            onTap: () => Get.to(() => ConnectedMemberDetailsScreen(member: m)),
          ),
        for (final p in controller.managedProfiles)
          _Person(
            name: p.fullName,
            initial: p.initial,
            tag: 'Managed'.tr,
            managed: true,
            locked: !p.canCare,
            onTap: () => Get.to(() => ManagedProfileDetailsScreen(profileId: p.id, name: p.fullName)),
          ),
      ];

      return Padding(
        padding: const EdgeInsets.only(bottom: XSizes.spaceBtwSections),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            XSectionHeading(title: controller.familyName, onPressed: _openFamily),
            if (people.isEmpty && !controller.isAdmin)
              Text('No other members yet.'.tr, style: textTheme.labelMedium)
            else
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: people.length + (controller.isAdmin ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(width: XSizes.md),
                  itemBuilder: (_, index) {
                    if (index == people.length) {
                      return _PersonTile(
                        label: 'Add'.tr,
                        semantics: 'Add family member'.tr,
                        onTap: () => Get.to(() => const AddMemberScreen()),
                        avatar: const CircleAvatar(
                          radius: 28,
                          backgroundColor: XColors.primary,
                          child: Icon(Iconsax.add, color: Colors.white),
                        ),
                      );
                    }
                    final person = people[index];
                    return _PersonTile(
                      label: person.name.split(' ').first,
                      tag: person.tag,
                      tagColor: person.managed ? const Color(0xFF9A6A00) : XColors.primaryDark,
                      semantics: '${person.name}, ${person.tag}',
                      onTap: person.onTap,
                      avatar: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: person.managed
                                ? XColors.secondary.withValues(alpha: 0.22)
                                : XColors.primaryBackground,
                            child: Text(
                              person.initial,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: person.managed ? const Color(0xFF9A6A00) : XColors.primaryDark,
                              ),
                            ),
                          ),
                          if (person.locked)
                            const Positioned(
                              right: -2,
                              bottom: -2,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.white,
                                child: Icon(Iconsax.lock_1, size: 12, color: XColors.darkGrey),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _Person {
  const _Person({
    required this.name,
    required this.initial,
    required this.tag,
    required this.managed,
    required this.onTap,
    this.locked = false,
  });

  final String name;
  final String initial;
  final String tag;
  final bool managed;
  final bool locked;
  final VoidCallback onTap;
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.label,
    required this.avatar,
    required this.semantics,
    required this.onTap,
    this.tag,
    this.tagColor,
  });

  final String label;
  final String? tag;
  final Color? tagColor;
  final Widget avatar;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semantics,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(XSizes.cardRadiusMd),
          child: SizedBox(
            width: 68,
            child: Column(
              children: [
                const SizedBox(height: XSizes.xs),
                avatar,
                const SizedBox(height: XSizes.xs),
                Text(label, style: textTheme.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (tag != null)
                  Text(
                    tag!,
                    style: textTheme.labelSmall!.apply(color: tagColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
