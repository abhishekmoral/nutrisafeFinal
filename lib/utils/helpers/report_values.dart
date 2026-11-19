/// -- Report value rules used in the app. They mirror the server rules in
/// supabase/functions/analyze-report/rules.ts; the server re-checks every value before
/// explaining, and only the server marks a value as critical.
class XReportValues {
  XReportValues._();

  static final _thousands = RegExp(r'(\d),(?=\d{3}\b)');
  static final _plainNumber = RegExp(r'^[+-]?\d+(\.\d+)?$');

  /// A plain printed number ("180", "12.5", "1,200"), or null for anything else
  /// ("<0.5", "Positive", "4-6"). Nothing is guessed.
  static double? parseNumeric(String text) {
    final cleaned = text.trim().replaceAllMapped(_thousands, (m) => m.group(1)!);
    if (!_plainNumber.hasMatch(cleaned)) return null;
    final value = double.tryParse(cleaned);
    return (value == null || !value.isFinite) ? null : value;
  }

  /// Compares a value with the range printed by the laboratory: low / high / normal / unknown.
  static String rangeFlag(double? value, double? low, double? high) {
    if (value == null || (low == null && high == null)) return 'unknown';
    if (low != null && high != null && low > high) return 'unknown';
    if (low != null && value < low) return 'low';
    if (high != null && value > high) return 'high';
    return 'normal';
  }
}
