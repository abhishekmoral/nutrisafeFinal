import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../controllers/medical_reports_controller.dart';
import '../widgets/report_consent_card.dart';
import 'widgets/report_tile.dart';

class MedicalReportsScreen extends StatelessWidget {
  const MedicalReportsScreen({super.key});

  void _chooseSource(BuildContext context, MedicalReportsController controller) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(XSizes.defaultSpace, 0, XSizes.defaultSpace, XSizes.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload a lab report'.tr, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: XSizes.xs),
              Text(
                'PDF, JPG or PNG. For photos, lay the page flat in good light so every value is sharp.'.tr,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: XSizes.sm),
              for (final (source, icon, label) in [
                (ReportSource.camera, Iconsax.camera, 'Take a photo'.tr),
                (ReportSource.gallery, Iconsax.gallery, 'Choose a photo'.tr),
                (ReportSource.pdf, Iconsax.document_text, 'Choose a PDF file'.tr),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: XColors.primary),
                  title: Text(label),
                  onTap: () {
                    Navigator.pop(context);
                    controller.addReport(source);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MedicalReportsController());
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Medical reports'.tr)),
      floatingActionButton: Obx(
        () => FloatingActionButton.extended(
          onPressed: controller.uploading.value ? null : () => _chooseSource(context, controller),
          icon: controller.uploading.value
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Iconsax.document_upload),
          label: Text(controller.uploading.value ? 'Uploading...'.tr : 'Upload report'.tr),
        ),
      ),
      body: Obx(() {
        if (controller.loading.value) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// Consent
              if (!controller.aiConsent.value) ...[
                XReportConsentCard(allowed: false, onChanged: controller.setAiConsent),
                const SizedBox(height: XSizes.spaceBtwSections),
              ],

              /// Reports
              if (controller.reports.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: XSizes.xl),
                  child: Column(
                    children: [
                      const Icon(Iconsax.document_text, size: 56, color: XColors.darkGrey),
                      const SizedBox(height: XSizes.spaceBtwItems),
                      Text('No reports yet'.tr, style: textTheme.titleLarge),
                      const SizedBox(height: XSizes.xs),
                      Text(
                        'Upload a blood test or other lab report to see its values explained in simple language.'.tr,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else
                for (final report in controller.reports)
                  XReportTile(report: report, onTap: () => controller.openReport(report)),

              const SizedBox(height: XSizes.spaceBtwItems),
              Text(
                'Your reports are stored privately. Only you can see them.'.tr,
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: 80), // room for the upload button
            ],
          ),
        );
      }),
    );
  }
}
