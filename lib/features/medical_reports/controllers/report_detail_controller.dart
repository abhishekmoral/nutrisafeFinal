import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../data/repositories/medical_reports/medical_report_repository.dart';
import '../../../utils/exceptions/exception_handler.dart';
import '../../../utils/popups/loaders.dart';
import '../models/medical_report_model.dart';
import '../models/report_result_model.dart';
import '../screens/report_detail/report_image_viewer.dart';

class ReportDetailController extends GetxController {
  ReportDetailController({required this.reportId, this.readNow = false});

  /// Variables
  final String reportId;
  final bool readNow; // start reading as soon as the screen opens (right after upload)
  final _repository = Get.put(MedicalReportRepository());
  final report = Rxn<MedicalReportModel>();
  final results = <ReportResultModel>[].obs;
  final analysis = Rxn<ReportAnalysisModel>();
  final aiConsent = false.obs;
  final loading = true.obs;
  final busy = RxnString(); // 'reading' | 'explaining' | 'saving' | null
  final lastError = RxnString(); // why the last read or explanation failed

  bool get hasCritical => results.any((r) => r.flag == 'critical');

  @override
  void onInit() {
    super.onInit();
    load().then((_) {
      if (readNow && aiConsent.value && report.value?.status == ReportStatus.uploaded) read();
    });
  }

  Future<void> load() async {
    try {
      final data = await Future.wait([
        _repository.fetchReport(reportId),
        _repository.fetchResults(reportId),
        _repository.fetchAnalysis(reportId),
        _repository.fetchAiConsent(),
      ]);
      report.value = data[0] as MedicalReportModel?;
      results.assignAll(data[1] as List<ReportResultModel>);
      analysis.value = data[2] as ReportAnalysisModel?;
      aiConsent.value = data[3] as bool;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not load the report'.tr, message: XExceptionHandler.message(e));
    } finally {
      loading.value = false;
    }
  }

  Future<void> setAiConsent(bool allowed) async {
    try {
      await _repository.setAiConsent(allowed);
      aiConsent.value = allowed;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// -- Step 1: the AI copies the printed values (the user checks them afterwards).
  Future<void> read() => _runReader('extract', 'reading');

  /// -- Step 2: explain the checked values in simple language.
  Future<void> explain() => _runReader('explain', 'explaining');

  Future<void> _runReader(String action, String state) async {
    if (busy.value != null) return;
    busy.value = state;
    lastError.value = null;
    try {
      await _repository.runReader(reportId, action);
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['code'] == 'consent_required') aiConsent.value = false;
      lastError.value = XExceptionHandler.message(e);
    } catch (e) {
      lastError.value = XExceptionHandler.message(e);
    } finally {
      busy.value = null;
      await load();
    }
  }

  /// -- Review step
  Future<bool> saveResult(ReportResultModel result) async {
    try {
      busy.value = 'saving';
      if (result.id == null) {
        await _repository.addResult(reportId, result);
      } else {
        await _repository.updateResult(result);
      }
      results.assignAll(await _repository.fetchResults(reportId));
      return true;
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not save'.tr, message: XExceptionHandler.message(e));
      return false;
    } finally {
      busy.value = null;
    }
  }

  Future<void> deleteResult(ReportResultModel result) async {
    if (result.id == null) return;
    try {
      await _repository.deleteResult(result.id!);
      results.removeWhere((r) => r.id == result.id);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not delete'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// Back to the review step (to correct values, or to type them in after a failed read).
  Future<void> reviewValues() async {
    try {
      await _repository.setStatus(reportId, ReportStatus.needsReview);
      await load();
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not change the report'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// -- Original file: photos open inside the app, PDFs in the phone's PDF viewer.
  Future<void> openOriginal() async {
    final current = report.value;
    if (current == null) return;
    try {
      if (current.isPdf) {
        final link = await _repository.temporaryLink(current.storagePath);
        final opened = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
        if (!opened) XLoaders.warningSnackBar(title: 'No app found to open PDF files'.tr);
      } else {
        final bytes = await _repository.downloadFile(current.storagePath);
        Get.to(() => ReportImageViewer(bytes: bytes, title: current.title));
      }
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not open the file'.tr, message: XExceptionHandler.message(e));
    }
  }

  /// -- Permanently delete the report, its file, values and explanation.
  Future<void> deleteReport() async {
    final current = report.value;
    if (current == null) return;
    try {
      busy.value = 'saving';
      await _repository.deleteReport(current);
      Get.back();
      XLoaders.successSnackBar(title: 'Report deleted'.tr);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not delete the report'.tr, message: XExceptionHandler.message(e));
    } finally {
      busy.value = null;
    }
  }
}
