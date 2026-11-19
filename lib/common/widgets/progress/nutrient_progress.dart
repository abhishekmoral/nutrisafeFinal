import 'package:flutter/material.dart';

import '../../../utils/helpers/helper_function.dart';

/// -- "Protein 42 / 60 g" with a progress bar. Works without a goal too.
class XNutrientProgress extends StatelessWidget {
  const XNutrientProgress({
    super.key,
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    required this.color,
  });

  final String label;
  final double? value;
  final double? goal;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final current = value ?? 0;
    final hasGoal = goal != null && goal! > 0;
    final progress = hasGoal ? (current / goal!).clamp(0.0, 1.0) : 0.0;
    final valueText = hasGoal
        ? '${XHelperFunctions.formatNumber(current, decimals: 0)} / '
              '${XHelperFunctions.formatNumber(goal, decimals: 0)} $unit'
        : '${XHelperFunctions.formatNumber(current, decimals: 0)} $unit';

    return Semantics(
      label: '$label $valueText',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: textTheme.labelLarge),
                Flexible(
                  child: Text(
                    valueText,
                    style: textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 8,
                color: color,
                backgroundColor: color.withValues(alpha: 0.18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
