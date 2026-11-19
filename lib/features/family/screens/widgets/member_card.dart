import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import 'member_type_badge.dart';

/// -- One family member in the Family list.
class XMemberCard extends StatelessWidget {
  const XMemberCard({
    super.key,
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.badges,
    this.onTap,
    this.trailing,
  });

  final String initial;
  final String title;
  final String subtitle;
  final List<MemberBadge> badges;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$title. $subtitle. ${badges.map((b) => b.label).join(', ')}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XSizes.cardRadiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: XSizes.sm),
          child: ExcludeSemantics(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: XColors.primaryBackground,
                  child: Text(
                    initial,
                    style: const TextStyle(color: XColors.primaryDark, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: XSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(subtitle, style: textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: XSizes.xs,
                        runSpacing: XSizes.xs,
                        children: [for (final b in badges) XMemberTypeBadge(badge: b)],
                      ),
                    ],
                  ),
                ),
                trailing ?? (onTap == null ? const SizedBox.shrink() : const Icon(Iconsax.arrow_right_3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
