import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../features/medical_reports/models/medical_report_model.dart';
import '../../../features/medical_reports/models/report_result_model.dart';
import '../../../utils/constants/api_constants.dart';
import '../user/user_repository.dart';

class MedicalReportRepository extends GetxController {
  static MedicalReportRepository get instance => Get.find();

  /// Files the reader accepts. Photos are kept small enough for the AI service.
  static const maxPdfBytes = 10 * 1024 * 1024;
  static const maxImageBytes = 3700 * 1024;

  final _supabase = Supabase.instance.client;
  final _userRepository = Get.put(UserRepository());

  String get _uid => _supabase.auth.currentUser!.id;

  StorageFileApi get _bucket => _supabase.storage.from(XApiConstants.medicalReportsBucket);

  /// -- Separate consent: may the AI service read my medical reports?
  Future<bool> fetchAiConsent() async {
    final permissions = await _userRepository.fetchAiPermissions();
    return permissions['medical_reports'] == true;
  }

  Future<void> setAiConsent(bool allowed) => _userRepository.setAiPermission('medical_reports', allowed);

  /// -- My own reports, newest first.
  Future<List<MedicalReportModel>> fetchReports() async {
    final rows = await _supabase
        .from('medical_reports')
        .select()
        .eq('owner_id', _uid)
        .isFilter('child_id', null)
        .order('created_at', ascending: false);
    return rows.map(MedicalReportModel.fromJson).toList();
  }

  Future<MedicalReportModel?> fetchReport(String id) async {
    final row = await _supabase.from('medical_reports').select().eq('id', id).maybeSingle();
    return row == null ? null : MedicalReportModel.fromJson(row);
  }

  /// -- Store the file privately in my own folder (named after my user id) and create the report row.
  Future<MedicalReportModel> uploadReport({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final extension = switch (mimeType) {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      _ => 'jpg',
    };
    final path = '$_uid/${const Uuid().v4()}.$extension';
    await _bucket.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType, upsert: false),
    );
    try {
      final row = await _supabase
          .from('medical_reports')
          .insert({
            'owner_id': _uid,
            'storage_path': path,
            'file_name': fileName.length > 120 ? fileName.substring(0, 120) : fileName,
            'mime_type': mimeType,
            'file_size': bytes.length,
          })
          .select()
          .single();
      return MedicalReportModel.fromJson(row);
    } catch (_) {
      // Do not leave an orphaned file behind.
      await _bucket.remove([path]);
      rethrow;
    }
  }

  /// -- Results and explanation
  Future<List<ReportResultModel>> fetchResults(String reportId) async {
    final rows = await _supabase
        .from('medical_report_results')
        .select()
        .eq('report_id', reportId)
        .order('created_at');
    return rows.map(ReportResultModel.fromJson).toList();
  }

  Future<ReportAnalysisModel?> fetchAnalysis(String reportId) async {
    final row = await _supabase
        .from('medical_report_analyses')
        .select()
        .eq('report_id', reportId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : ReportAnalysisModel.fromJson(row);
  }

  Future<void> updateResult(ReportResultModel result) async {
    await _supabase
        .from('medical_report_results')
        .update({...result.toJson(), 'is_user_verified': true})
        .eq('id', result.id!);
  }

  Future<void> addResult(String reportId, ReportResultModel result) async {
    await _supabase
        .from('medical_report_results')
        .insert({...result.toJson(), 'report_id': reportId, 'is_user_verified': true});
  }

  Future<void> deleteResult(String id) async {
    await _supabase.from('medical_report_results').delete().eq('id', id);
  }

  Future<void> setStatus(String reportId, ReportStatus status) async {
    await _supabase.from('medical_reports').update({'status': status.value}).eq('id', reportId);
  }

  /// -- Ask the server to read ("extract") or explain ("explain") the report.
  Future<Map<String, dynamic>> runReader(String reportId, String action) async {
    final response = await _supabase.functions
        .invoke(
          XApiConstants.analyzeReportFunction,
          body: {'report_id': reportId, 'action': action},
        )
        .timeout(const Duration(seconds: 170));
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// -- The original file
  Future<Uint8List> downloadFile(String storagePath) => _bucket.download(storagePath);

  /// Short-lived private link for opening a PDF in another app.
  Future<String> temporaryLink(String storagePath) => _bucket.createSignedUrl(storagePath, 300);

  /// -- Delete the file, then the report with its results and explanation.
  Future<void> deleteReport(MedicalReportModel report) async {
    await _bucket.remove([report.storagePath]);
    await _supabase.from('medical_reports').delete().eq('id', report.id);
  }
}
