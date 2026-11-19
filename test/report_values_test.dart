import 'package:flutter_test/flutter_test.dart';
import 'package:nutrisafe/features/medical_reports/models/report_result_model.dart';
import 'package:nutrisafe/utils/helpers/report_values.dart';

void main() {
  // Same cases as supabase/functions/tests/report_rules_test.ts, so app and server agree.
  group('XReportValues.parseNumeric', () {
    test('reads plain printed numbers only', () {
      expect(XReportValues.parseNumeric('180'), 180);
      expect(XReportValues.parseNumeric(' 12.5 '), 12.5);
      expect(XReportValues.parseNumeric('1,200'), 1200);
      expect(XReportValues.parseNumeric('1,50,000'), isNull);
      expect(XReportValues.parseNumeric('<0.5'), isNull);
      expect(XReportValues.parseNumeric('Positive'), isNull);
      expect(XReportValues.parseNumeric('4-6'), isNull);
      expect(XReportValues.parseNumeric(''), isNull);
    });
  });

  group('XReportValues.rangeFlag', () {
    test('compares with the laboratory range', () {
      expect(XReportValues.rangeFlag(180, 200, 900), 'low');
      expect(XReportValues.rangeFlag(18, 30, 100), 'low');
      expect(XReportValues.rangeFlag(450, 200, 900), 'normal');
      expect(XReportValues.rangeFlag(200, 200, 900), 'normal');
      expect(XReportValues.rangeFlag(950, 200, 900), 'high');
      expect(XReportValues.rangeFlag(250, null, 200), 'high');
      expect(XReportValues.rangeFlag(45, 40, null), 'normal');
      expect(XReportValues.rangeFlag(180, null, null), 'unknown');
      expect(XReportValues.rangeFlag(null, 200, 900), 'unknown');
      expect(XReportValues.rangeFlag(5, 10, 2), 'unknown');
    });
  });

  group('ReportResultModel', () {
    final b12 = ReportResultModel(
      id: 'r1',
      testName: 'Vitamin B12',
      valueText: '180',
      unit: 'pg/mL',
      referenceLow: 200,
      referenceHigh: 900,
      referenceText: '200 - 900',
      flag: 'low',
    );

    test('shows the range exactly as printed', () {
      expect(b12.rangeLabel, '200 - 900');
      expect(b12.isOutOfRange, isTrue);
      expect(b12.valueNumeric, 180);
    });

    test('a corrected value is compared again, the printed range is kept', () {
      final fixed = b12.edited(
        testName: 'Vitamin B12',
        valueText: '310',
        unit: 'pg/mL',
        referenceLow: 200,
        referenceHigh: 900,
      );
      expect(fixed.id, 'r1');
      expect(fixed.flag, 'normal');
      expect(fixed.referenceText, '200 - 900');
    });

    test('changed limits drop the old printed range text', () {
      final fixed = b12.edited(
        testName: 'Vitamin B12',
        valueText: '180',
        unit: 'pg/mL',
        referenceLow: 150,
        referenceHigh: 900,
      );
      expect(fixed.referenceText, isNull);
      expect(fixed.rangeLabel, '150 - 900');
      expect(fixed.flag, 'normal');
    });

    test('a value that is not a number cannot be judged', () {
      final text = b12.edited(testName: 'Vitamin B12', valueText: '<150', unit: 'pg/mL', referenceLow: 200, referenceHigh: 900);
      expect(text.flag, 'unknown');
      expect(text.toJson()['value_numeric'], isNull);
    });

    test('one-sided ranges are labelled clearly', () {
      final ldl = ReportResultModel(testName: 'LDL', valueText: '120', referenceHigh: 100);
      expect(ldl.rangeLabel, '< 100');
      expect(ReportResultModel(testName: 'X', valueText: '1').rangeLabel, isNull);
    });
  });
}
