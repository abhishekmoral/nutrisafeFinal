import '../../../utils/helpers/helper_function.dart';
import '../../../utils/helpers/report_values.dart';

/// -- One test result read from a report, stored exactly as printed (`medical_report_results`).
class ReportResultModel {
  ReportResultModel({
    this.id,
    required this.testName,
    required this.valueText,
    this.unit,
    this.referenceLow,
    this.referenceHigh,
    this.referenceText,
    this.flag = 'unknown',
  });

  final String? id;
  final String testName;
  final String valueText; // exactly as printed, e.g. "180", "<0.5", "Positive"
  final String? unit;
  final double? referenceLow;
  final double? referenceHigh;
  final String? referenceText; // the laboratory's range as printed
  final String flag; // low | high | normal | critical | unknown

  double? get valueNumeric => XReportValues.parseNumeric(valueText);

  bool get isOutOfRange => flag == 'low' || flag == 'high' || flag == 'critical';

  /// The lab's range as printed, or built from the limits, or null when none was printed.
  String? get rangeLabel {
    if (referenceText != null && referenceText!.isNotEmpty) return referenceText;
    if (referenceLow == null && referenceHigh == null) return null;
    if (referenceLow != null && referenceHigh != null) {
      return '${XHelperFunctions.formatNumber(referenceLow, decimals: 2)} - '
          '${XHelperFunctions.formatNumber(referenceHigh, decimals: 2)}';
    }
    return referenceLow != null
        ? '> ${XHelperFunctions.formatNumber(referenceLow, decimals: 2)}'
        : '< ${XHelperFunctions.formatNumber(referenceHigh, decimals: 2)}';
  }

  /// A copy with new values. The flag is recomputed from the lab range (the server
  /// re-checks everything, including critical values, before explaining).
  ReportResultModel edited({
    required String testName,
    required String valueText,
    String? unit,
    double? referenceLow,
    double? referenceHigh,
  }) {
    final limitsChanged = referenceLow != this.referenceLow || referenceHigh != this.referenceHigh;
    return ReportResultModel(
      id: id,
      testName: testName,
      valueText: valueText,
      unit: unit,
      referenceLow: referenceLow,
      referenceHigh: referenceHigh,
      // A printed range no longer matches limits the user changed.
      referenceText: limitsChanged ? null : referenceText,
      flag: XReportValues.rangeFlag(XReportValues.parseNumeric(valueText), referenceLow, referenceHigh),
    );
  }

  static double? _num(dynamic value) => value == null ? null : (value as num).toDouble();

  factory ReportResultModel.fromJson(Map<String, dynamic> json) {
    return ReportResultModel(
      id: json['id'] as String?,
      testName: json['test_name'] as String,
      valueText: json['value_text'] as String,
      unit: json['unit'] as String?,
      referenceLow: _num(json['reference_low']),
      referenceHigh: _num(json['reference_high']),
      referenceText: json['reference_text'] as String?,
      flag: json['flag'] as String? ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'test_name': testName,
      'value_text': valueText,
      'value_numeric': valueNumeric,
      'unit': unit,
      'reference_low': referenceLow,
      'reference_high': referenceHigh,
      'reference_text': referenceText,
      'flag': flag,
    };
  }
}

/// -- The plain-language explanation of a report (`medical_report_analyses`).
class ReportAnalysisModel {
  ReportAnalysisModel({
    required this.summary,
    this.nutritionGuidance,
    this.urgentGuidance,
    required this.language,
    required this.createdAt,
  });

  final String summary;
  final String? nutritionGuidance;
  final String? urgentGuidance;
  final String language;
  final DateTime createdAt;

  factory ReportAnalysisModel.fromJson(Map<String, dynamic> json) {
    return ReportAnalysisModel(
      summary: json['summary'] as String,
      nutritionGuidance: json['nutrition_guidance'] as String?,
      urgentGuidance: json['urgent_guidance'] as String?,
      language: json['language'] as String? ?? 'en',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}
