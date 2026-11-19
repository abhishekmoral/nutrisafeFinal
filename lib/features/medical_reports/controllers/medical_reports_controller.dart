import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/repositories/medical_reports/medical_report_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/medical_report_model.dart';
import '../screens/report_detail/report_detail.dart';

/// Where a new report comes from.
enum ReportSource { camera, gallery, pdf }

class MedicalReportsController extends GetxController {
  static MedicalReportsController get instance => Get.find();

  /// Variables
  final _repository = Get.put(MedicalReportRepository());
  final reports = <MedicalReportModel>[].obs;
  final aiConsent = false.obs;
  final loading = true.obs;
  final uploading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      final results = await Future.wait([_repository.fetchReports(), _repository.fetchAiConsent()]);
      reports.assignAll(results[0] as List<MedicalReportModel>);
      aiConsent.value = results[1] as bool;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load reports'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  Future<void> setAiConsent(bool allowed) async {
    final previous = aiConsent.value;
    aiConsent.value = allowed;
    try {
      await _repository.setAiConsent(allowed);
    } catch (e) {
      aiConsent.value = previous;
      XLoaders.errorSnackBar(title: 'Could not save'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// -- Pick a file, check it, upload it privately and open it.
  Future<void> addReport(ReportSource source) async {
    if (uploading.value) return;
    try {
      final picked = await _pick(source);
      if (picked == null) return; // the user cancelled

      final mimeType = _mimeType(picked.name);
      if (mimeType == null) {
        XLoaders.warningSnackBar(title: 'File type not supported'.tr, message: 'Please choose a PDF, JPG or PNG file.'.tr);
        return;
      }
      final limit = mimeType == 'application/pdf'
          ? MedicalReportRepository.maxPdfBytes
          : MedicalReportRepository.maxImageBytes;
      if (picked.bytes.isEmpty || picked.bytes.length > limit) {
        XLoaders.warningSnackBar(
          title: 'File too large'.tr,
          message: mimeType == 'application/pdf'
              ? 'PDF reports can be up to 10 MB.'.tr
              : 'Photos can be up to 3.7 MB. Take the photo again or upload a PDF.'.tr,
        );
        return;
      }

      uploading.value = true;
      final report = await _repository.uploadReport(
        bytes: picked.bytes,
        fileName: picked.name,
        mimeType: mimeType,
      );
      uploading.value = false;
      await load();
      await Get.to(() => ReportDetailScreen(reportId: report.id, readNow: aiConsent.value));
      await load();
    } on PlatformException catch (e) {
      final denied = e.code.contains('denied') || e.code.contains('access');
      XLoaders.errorSnackBar(
        title: denied ? 'Permission needed'.tr : 'Could not open the file'.tr,
        message: denied
            ? 'Allow camera or photo access for NutriSafe in your phone settings.'.tr
            : 'Please try again or choose another file.'.tr,
      );
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Upload failed'.tr, message: XExceptionHandler.message(e));
    } finally {
      uploading.value = false;
    }
  }

  Future<({String name, Uint8List bytes})?> _pick(ReportSource source) async {
    switch (source) {
      case ReportSource.camera:
      case ReportSource.gallery:
        // Photos are resized and compressed so they stay readable but small.
        final photo = await ImagePicker().pickImage(
          source: source == ReportSource.camera ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 2200,
          maxHeight: 2200,
          imageQuality: 85,
        );
        if (photo == null) return null;
        return (name: photo.name, bytes: await photo.readAsBytes());
      case ReportSource.pdf:
        final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['pdf']);
        if (file == null) return null;
        return (name: file.name, bytes: await file.readAsBytes());
    }
  }

  static String? _mimeType(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) return 'image/jpeg';
    return null;
  }

  Future<void> openReport(MedicalReportModel report) async {
    await Get.to(() => ReportDetailScreen(reportId: report.id));
    await load();
  }
}
