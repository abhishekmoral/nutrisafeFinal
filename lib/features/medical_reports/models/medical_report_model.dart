import 'package:get/get.dart';

/// -- Processing state of an uploaded report (`medical_reports.status`).
enum ReportStatus {
  uploaded('uploaded', 'Not read yet'),
  processing('processing', 'Reading...'),
  needsReview('needs_review', 'Check values'),
  analyzed('analyzed', 'Explained'),
  failed('failed', 'Could not read');

  const ReportStatus(this.value, this._label);
  final String value;
  final String _label;

  /// Shown to the user, in the app language.
  String get label => _label.tr;

  static ReportStatus fromValue(String? value) =>
      ReportStatus.values.firstWhere((e) => e.value == value, orElse: () => ReportStatus.uploaded);
}

/// -- An uploaded medical report (`medical_reports` table). The file itself is in private storage.
class MedicalReportModel {
  MedicalReportModel({
    required this.id,
    required this.ownerId,
    required this.storagePath,
    required this.fileName,
    required this.mimeType,
    this.fileSize,
    this.reportDate,
    this.labName,
    this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  static const categoryLabels = {
    'cbc': 'Complete blood count',
    'vitamin_b12': 'Vitamin B12',
    'vitamin_d': 'Vitamin D',
    'blood_glucose': 'Blood glucose',
    'hba1c': 'HbA1c',
    'thyroid': 'Thyroid profile',
    'lipid': 'Lipid profile',
    'liver': 'Liver function',
    'kidney': 'Kidney function',
    'iron': 'Iron profile',
    'other': 'Lab report',
  };

  final String id;
  final String ownerId;
  final String storagePath;
  final String fileName;
  final String mimeType;
  final int? fileSize;
  final DateTime? reportDate;
  final String? labName;
  final String? category;
  final ReportStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPdf => mimeType == 'application/pdf';

  String get title => categoryLabels[category]?.tr ?? fileName;

  /// "Reading" for more than 4 minutes means the reader stopped without an answer.
  bool get isStuck =>
      status == ReportStatus.processing && DateTime.now().difference(updatedAt).inMinutes >= 4;

  factory MedicalReportModel.fromJson(Map<String, dynamic> json) {
    return MedicalReportModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      storagePath: json['storage_path'] as String,
      fileName: json['file_name'] as String,
      mimeType: json['mime_type'] as String,
      fileSize: (json['file_size'] as num?)?.toInt(),
      reportDate: json['report_date'] == null ? null : DateTime.parse(json['report_date'] as String),
      labName: json['lab_name'] as String?,
      category: json['category'] as String?,
      status: ReportStatus.fromValue(json['status'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}
