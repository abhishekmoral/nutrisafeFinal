import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../models/medical_report_model.dart';

class XReportTile extends StatelessWidget {
  const XReportTile({super.key, required this.report, required this.onTap});

  final MedicalReportModel report;
  final VoidCallback onTap;

  static Color statusColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.analyzed:
        return XColors.success;
      case ReportStatus.needsReview:
        return XColors.warning;
      case ReportStatus.failed:
        return XColors.error;
      case ReportStatus.processing:
      case ReportStatus.uploaded:
        return XColors.darkGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = report.reportDate ?? report.createdAt;
    final color = statusColor(report.status);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: XColors.primaryBackground,
        child: Icon(report.isPdf ? Iconsax.document_text : Iconsax.gallery, color: XColors.primary),
      ),
      title: Text(report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (report.labName != null && report.labName!.isNotEmpty) report.labName!,
          XHelperFunctions.getFormattedDate(date),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: XSizes.sm, vertical: XSizes.xs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(XSizes.borderRadiusLg),
        ),
        child: Text(report.status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
