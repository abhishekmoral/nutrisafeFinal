import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';

/// Kinds of badge shown on a family member.
enum MemberBadge {
  connected('Connected', XColors.primary),
  admin('Admin', XColors.info),
  managed('Managed', XColors.secondary),
  pending('Pending', XColors.warning),
  you('You', XColors.darkGrey);

  const MemberBadge(this._label, this.color);
  final String _label;

  /// Shown to the user, in the app language.
  String get label => _label.tr;
  final Color color;
}

class XMemberTypeBadge extends StatelessWidget {
  const XMemberTypeBadge({super.key, required this.badge, this.label});

  final MemberBadge badge;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: XSizes.sm, vertical: 3),
      decoration: BoxDecoration(
        color: badge.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(XSizes.borderRadiusLg),
      ),
      child: Text(
        label ?? badge.label,
        style: TextStyle(
          color: badge == MemberBadge.managed ? const Color(0xFF9A6A00) : badge.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
