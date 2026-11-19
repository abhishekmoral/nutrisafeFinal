import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../controllers/report_detail_controller.dart';
import '../../models/medical_report_model.dart';
import '../../models/report_result_model.dart';
import '../widgets/report_consent_card.dart';
import 'widgets/edit_result_sheet.dart';
import 'widgets/result_tile.dart';
import '../../../../utils/localization/translations.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.reportId, this.readNow = false});

  final String reportId;
  final bool readNow;

  Future<void> _confirmDelete(BuildContext context, ReportDetailController controller) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this report?'.tr),
        content: Text(
          'The file, its values and the explanation will be permanently deleted. This cannot be undone.'.tr,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete'.tr, style: TextStyle(color: XColors.error)),
          ),
        ],
      ),
    );
    if (delete == true) controller.deleteReport();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ReportDetailController(reportId: reportId, readNow: readNow), tag: reportId);
    return Scaffold(
      appBar: XAppBar(
        showBackArrow: true,
        title: Obx(() => Text(controller.report.value?.title ?? 'Report'.tr, overflow: TextOverflow.ellipsis)),
        actions: [
          IconButton(
            tooltip: 'Open the original file'.tr,
            onPressed: controller.openOriginal,
            icon: const Icon(Iconsax.document_text),
          ),
          IconButton(
            tooltip: 'Delete report'.tr,
            onPressed: () => _confirmDelete(context, controller),
            icon: const Icon(Iconsax.trash),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.loading.value) return const Center(child: CircularProgressIndicator());
        final report = controller.report.value;
        if (report == null) return Center(child: Text('This report was not found.'.tr));

        final busy = controller.busy.value;
        if (busy == 'reading' || busy == 'explaining') {
          return _Progress(
            title: busy == 'reading' ? 'Reading your report...'.tr : 'Writing the explanation...'.tr,
            subtitle: 'This can take up to a minute. You can leave this screen; the result is saved when it is ready.'.tr,
          );
        }

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              _Header(report: report),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Fixed urgent notice: shown whenever a value broke a critical rule.
              if (controller.hasCritical) ...[
                _UrgentNotice(text: controller.analysis.value?.urgentGuidance ?? XTexts.reportCriticalNotice),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],

              /// Last error
              if (controller.lastError.value != null) ...[
                _ErrorCard(message: controller.lastError.value!),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],

              ..._sectionFor(context, controller, report),

              const SizedBox(height: XSizes.spaceBtwSections),
              Text(XTexts.reportDisclaimer, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        );
      }),
    );
  }

  List<Widget> _sectionFor(BuildContext context, ReportDetailController controller, MedicalReportModel report) {
    final consentCard = XReportConsentCard(allowed: controller.aiConsent.value, onChanged: controller.setAiConsent);

    switch (report.status) {
      /// -- Not read yet, or reading failed
      case ReportStatus.uploaded:
      case ReportStatus.failed:
        return [
          if (report.status == ReportStatus.failed && controller.lastError.value == null)
            _ErrorCard(message: 'The AI could not read this report.'.tr),
          if (report.status == ReportStatus.failed) const SizedBox(height: XSizes.spaceBtwItems),
          if (!controller.aiConsent.value) ...[consentCard, const SizedBox(height: XSizes.spaceBtwItems)],
          if (controller.aiConsent.value)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: controller.read,
                icon: const Icon(Iconsax.scan),
                label: Text(report.status == ReportStatus.failed ? 'Try reading again'.tr : 'Read this report'.tr),
              ),
            ),
          const SizedBox(height: XSizes.spaceBtwItems),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.reviewValues,
              icon: const Icon(Iconsax.edit),
              label: Text('Type the values in myself'.tr),
            ),
          ),
        ];

      /// -- Reading on the server
      case ReportStatus.processing:
        return [
          XRoundedContainer(
            child: Text(
              report.isStuck
                  ? 'Reading did not finish. Please try again.'.tr
                  : 'This report is still being read. Pull down to refresh.'.tr,
            ),
          ),
          if (report.isStuck && controller.aiConsent.value) ...[
            const SizedBox(height: XSizes.spaceBtwItems),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(onPressed: controller.read, child: Text('Try reading again'.tr)),
            ),
          ],
        ];

      /// -- The user checks every value
      case ReportStatus.needsReview:
        return [
          XRoundedContainer(
            backgroundColor: XColors.warning.withValues(alpha: 0.12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Iconsax.eye, color: XColors.warning),
                const SizedBox(width: XSizes.sm),
                Expanded(child: Text(XTexts.reportReviewIntro, style: Theme.of(context).textTheme.bodyMedium)),
              ],
            ),
          ),
          const SizedBox(height: XSizes.spaceBtwItems),
          XSectionHeading(
            title: 'Values ({count})'.trf({'count': controller.results.length}),
            buttonTitle: 'Add test'.tr,
            onPressed: () => _editResult(context, controller, null),
          ),
          if (controller.results.isEmpty)
            Text('No values yet. Use "Add test" to type them in.'.tr, style: Theme.of(context).textTheme.labelMedium),
          for (final result in controller.results)
            XResultTile(
              result: result,
              onEdit: () => _editResult(context, controller, result),
              onDelete: () => _confirmRemove(context, controller, result),
            ),
          const SizedBox(height: XSizes.spaceBtwSections),
          if (!controller.aiConsent.value) ...[consentCard, const SizedBox(height: XSizes.spaceBtwItems)],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: controller.aiConsent.value && controller.results.isNotEmpty && controller.busy.value == null
                  ? controller.explain
                  : null,
              icon: const Icon(Iconsax.tick_circle),
              label: Text('Values are correct, explain them'.tr),
            ),
          ),
        ];

      /// -- Explained
      case ReportStatus.analyzed:
        final analysis = controller.analysis.value;
        final textTheme = Theme.of(context).textTheme;
        return [
          if (analysis != null) ...[
            XRoundedContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.magic_star, color: XColors.primary),
                      const SizedBox(width: XSizes.sm),
                      Expanded(child: Text('What your results mean'.tr, style: textTheme.titleLarge)),
                    ],
                  ),
                  Text('Written by AI · educational only'.tr, style: textTheme.labelMedium),
                  const SizedBox(height: XSizes.sm),
                  SelectableText(analysis.summary, style: textTheme.bodyMedium),
                ],
              ),
            ),
            if (analysis.nutritionGuidance != null && analysis.nutritionGuidance!.isNotEmpty) ...[
              const SizedBox(height: XSizes.spaceBtwItems),
              XRoundedContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Iconsax.reserve, color: XColors.primary),
                        const SizedBox(width: XSizes.sm),
                        Expanded(child: Text('Food and lifestyle (general)'.tr, style: textTheme.titleLarge)),
                      ],
                    ),
                    const SizedBox(height: XSizes.sm),
                    SelectableText(analysis.nutritionGuidance!, style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
            const SizedBox(height: XSizes.sm),
            Text(
              'Explained on {date}'.trf({'date': XHelperFunctions.getFormattedDate(analysis.createdAt)}),
              style: textTheme.labelMedium,
            ),
          ],
          const SizedBox(height: XSizes.spaceBtwSections),
          XSectionHeading(title: 'Values ({count})'.trf({'count': controller.results.length}), showActionButton: false),
          for (final result in controller.results) XResultTile(result: result),
          const SizedBox(height: XSizes.spaceBtwItems),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: controller.reviewValues,
              icon: const Icon(Iconsax.edit),
              label: Text('Correct a value'.tr),
            ),
          ),
        ];
    }
  }

  Future<void> _editResult(BuildContext context, ReportDetailController controller, ReportResultModel? result) async {
    final edited = await showModalBottomSheet<ReportResultModel>(
      context: context,
      isScrollControlled: true,
      builder: (_) => XEditResultSheet(result: result),
    );
    if (edited != null) await controller.saveResult(edited);
  }

  Future<void> _confirmRemove(BuildContext context, ReportDetailController controller, ReportResultModel result) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove this test?'.tr),
        content: Text('{testName} will be removed from this report\'s values.'.trf({'testName': result.testName})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove'.tr)),
        ],
      ),
    );
    if (remove == true) controller.deleteResult(result);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.report});

  final MedicalReportModel report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(report.title, style: textTheme.headlineSmall),
        Text(
          [
            if (report.labName != null && report.labName!.isNotEmpty) report.labName!,
            if (report.reportDate != null) 'Report date {date}'.trf({'date': XHelperFunctions.getFormattedDate(report.reportDate!)}),
            'Uploaded {date}'.trf({'date': XHelperFunctions.getFormattedDate(report.createdAt)}),
          ].join(' · '),
          style: textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _UrgentNotice extends StatelessWidget {
  const _UrgentNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return XRoundedContainer(
      backgroundColor: XColors.error.withValues(alpha: 0.12),
      showBorder: true,
      borderColor: XColors.error,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.danger, color: XColors.error),
          const SizedBox(width: XSizes.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return XRoundedContainer(
      backgroundColor: XColors.error.withValues(alpha: 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.info_circle, color: XColors.error),
          const SizedBox(width: XSizes.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(XSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: XSizes.spaceBtwSections),
            Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: XSizes.sm),
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
