import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/localization/translations.dart';
import '../../models/insights_summary.dart';

/// -- One bar per day for the chosen nutrient, with the goal (or limit) as a dashed line.
/// Days without data show a short grey stub. Tapping a bar selects that day.
class XMetricChart extends StatelessWidget {
  const XMetricChart({
    super.key,
    required this.summary,
    required this.metric,
    required this.goal,
    required this.selectedDay,
    required this.onDayTap,
  });

  final InsightsSummary summary;
  final InsightMetric metric;
  final double? goal;
  final DateTime? selectedDay;
  final ValueChanged<DateTime> onDayTap;

  static const _chartHeight = 150.0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final days = summary.days;
    final values = days.map((d) => summary.valueOn(metric, d)).toList();
    final hasGoal = goal != null && goal! > 0;
    final maxValue = [...values.whereType<double>(), if (hasGoal) goal! * 1.1, 1.0].reduce((a, b) => a > b ? a : b);
    final many = days.length > 10;
    final labelEvery = days.length > 20 ? 5 : (many ? 2 : 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _chartHeight + 22,
          child: Stack(
            children: [
              // Bars
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < days.length; i++)
                      Expanded(
                        child: _Bar(
                          day: days[i],
                          value: values[i],
                          height: _chartHeight * (values[i] ?? 0) / maxValue,
                          color: _barColor(values[i]),
                          selected: DateUtils.isSameDay(selectedDay, days[i]),
                          label: i % labelEvery == (days.length - 1) % labelEvery
                              ? (many ? DateFormat('d').format(days[i]) : DateFormat('E').format(days[i]))
                              : '',
                          showValue: !many,
                          unit: metric.unit,
                          onTap: () => onDayTap(days[i]),
                        ),
                      ),
                  ],
                ),
              ),
              // Goal line
              if (hasGoal)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 22 + _chartHeight * goal! / maxValue,
                  child: IgnorePointer(child: CustomPaint(size: const Size(double.infinity, 1), painter: _DashedLine())),
                ),
            ],
          ),
        ),
        const SizedBox(height: XSizes.sm),
        Wrap(
          spacing: XSizes.md,
          runSpacing: XSizes.xs,
          children: [
            _Legend(color: metric.color, text: metric.label),
            if (hasGoal)
              _Legend(
                dashed: true,
                color: XColors.darkGrey,
                text: (metric.isLimit ? 'Limit {value} {unit}' : 'Goal {value} {unit}')
                    .trf({'value': XHelperFunctions.formatNumber(goal, decimals: 0), 'unit': metric.unit}),
              ),
            if (hasGoal && metric.isLimit) _Legend(color: XColors.error, text: 'Above limit'.tr),
            _Legend(color: XColors.grey, text: 'Not logged'.tr),
          ],
        ),
        if (!hasGoal)
          Padding(
            padding: const EdgeInsets.only(top: XSizes.xs),
            child: Text('No goal set for {nutrient}.'.trf({'nutrient': metric.label.toLowerCase()}), style: textTheme.labelSmall),
          ),
      ],
    );
  }

  Color _barColor(double? value) {
    if (value == null) return XColors.grey;
    if (metric.isLimit && goal != null && value > goal!) return XColors.error;
    return metric.color;
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.value,
    required this.height,
    required this.color,
    required this.selected,
    required this.label,
    required this.showValue,
    required this.unit,
    required this.onTap,
  });

  final DateTime day;
  final double? value;
  final double height;
  final Color color;
  final bool selected;
  final String label;
  final bool showValue;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dayName = DateFormat('EEEE d MMM').format(day);
    return Semantics(
      button: true,
      selected: selected,
      label: value == null
          ? '{day}: not logged'.trf({'day': dayName})
          : '$dayName: ${XHelperFunctions.formatNumber(value, decimals: 0)} $unit',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (showValue)
                FittedBox(
                  child: Text(
                    value == null ? '–' : XHelperFunctions.formatNumber(value, decimals: 0),
                    style: textTheme.labelSmall,
                  ),
                ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: value == null ? 3 : height.clamp(3, double.infinity),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                decoration: BoxDecoration(
                  color: selected ? color : color.withValues(alpha: value == null ? 1 : 0.85),
                  borderRadius: BorderRadius.circular(4),
                  border: selected ? Border.all(color: XColors.textPrimary, width: 1.5) : null,
                ),
              ),
              SizedBox(
                height: 20,
                child: Center(
                  child: FittedBox(
                    child: Text(
                      label,
                      style: textTheme.labelSmall!.copyWith(fontWeight: selected ? FontWeight.w700 : null),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedLine extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = XColors.darkGrey
      ..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text, this.dashed = false});

  final Color color;
  final String text;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed
            ? SizedBox(width: 14, height: 2, child: CustomPaint(painter: _DashedLine()))
            : Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
