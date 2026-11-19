import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/enums.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../../utils/localization/translations.dart';
import '../../../controllers/food_diary_controller.dart';

/// -- Today at a glance: calories as a ring, macros as bars, sugar and sodium against their limits.
/// Calculated from today's diary and the user's own goals.
class XHomeTodayCard extends StatelessWidget {
  const XHomeTodayCard({super.key});

  static String _n(double? v) => XHelperFunctions.formatNumber(v ?? 0, decimals: 0);

  @override
  Widget build(BuildContext context) {
    final diary = FoodDiaryController.instance;
    final textTheme = Theme.of(context).textTheme;
    final dark = XHelperFunctions.isDarkMode(context);

    return Obx(() {
      final today = DateTime.now();
      final totals = diary.totalsOn(today);
      final goals = diary.goals.value;
      final eaten = totals.calories ?? 0;
      final goal = goals?.calories;
      final mealsLogged = MealType.values.where((m) => diary.entriesFor(today, m).isNotEmpty).length;
      final unknown = diary.unknownCaloriesCount(today);

      String status;
      Color statusColor;
      if (goal == null || goal <= 0) {
        status = 'Set a calorie goal in your profile'.tr;
        statusColor = XColors.darkGrey;
      } else if (eaten <= goal) {
        status = '{value} kcal left'.trf({'value': _n(goal - eaten)});
        statusColor = XColors.primary;
      } else {
        status = '{value} kcal over your goal'.trf({'value': _n(eaten - goal)});
        statusColor = XColors.warning;
      }

      return XRoundedContainer(
        backgroundColor: dark ? XColors.darkContainer : XColors.primaryBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                /// Calorie ring
                Semantics(
                  label: goal == null
                      ? '{value} kilocalories eaten today'.trf({'value': _n(eaten)})
                      : '{value} of {goal} kilocalories eaten today'.trf({'value': _n(eaten), 'goal': _n(goal)}),
                  child: ExcludeSemantics(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: _RingPainter(
                          progress: goal == null || goal <= 0 ? 0 : eaten / goal,
                          color: goal != null && eaten > goal ? XColors.warning : XColors.calories,
                          track: XColors.calories.withValues(alpha: 0.18),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_n(eaten), style: textTheme.headlineSmall),
                              Text(
                                goal == null ? 'kcal'.tr : '/ {goal} kcal'.trf({'goal': _n(goal)}),
                                style: textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: XSizes.md),

                /// Status and macros
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status, style: textTheme.titleMedium!.copyWith(color: statusColor)),
                      const SizedBox(height: XSizes.sm),
                      _MiniBar(
                        label: 'Protein'.tr,
                        value: totals.proteinG,
                        goal: goals?.proteinG,
                        unit: 'g',
                        color: XColors.protein,
                      ),
                      _MiniBar(
                        label: 'Carbs'.tr,
                        value: totals.carbsG,
                        goal: goals?.carbsG,
                        unit: 'g',
                        color: XColors.carbs,
                      ),
                      _MiniBar(label: 'Fat'.tr, value: totals.fatG, goal: goals?.fatG, unit: 'g', color: XColors.fat),
                      _MiniBar(
                        label: 'Fiber'.tr,
                        value: totals.fiberG,
                        goal: goals?.fiberG,
                        unit: 'g',
                        color: XColors.fiber,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Limits and meals
            Wrap(
              spacing: XSizes.sm,
              runSpacing: XSizes.xs,
              children: [
                _LimitChip(label: 'Sugar'.tr, value: totals.sugarG, limit: goals?.sugarG, unit: 'g'),
                _LimitChip(label: 'Sodium'.tr, value: totals.sodiumMg, limit: goals?.sodiumMg, unit: 'mg'),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('{count}/4 meals logged'.trf({'count': mealsLogged})),
                ),
              ],
            ),
            if (unknown > 0)
              Padding(
                padding: const EdgeInsets.only(top: XSizes.xs),
                child: Text(
                  unknown == 1
                      ? '1 item without nutrition data is not included in these totals.'.tr
                      : '{count} items without nutrition data are not included in these totals.'.trf({
                          'count': unknown,
                        }),
                  style: textTheme.labelSmall,
                ),
              ),
          ],
        ),
      );
    });
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({
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
    final v = value ?? 0;
    final hasGoal = goal != null && goal! > 0;
    final text = hasGoal
        ? '${XHelperFunctions.formatNumber(v, decimals: 0)}/${XHelperFunctions.formatNumber(goal, decimals: 0)} $unit'
        : '${XHelperFunctions.formatNumber(v, decimals: 0)} $unit';
    return Semantics(
      label: '$label $text',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(label, style: textTheme.labelMedium)),
                  Text(text, style: textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: hasGoal ? (v / goal!).clamp(0.0, 1.0) : 0,
                  minHeight: 5,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Sugar 18/30 g" - turns red above the limit.
class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.label, required this.value, required this.limit, required this.unit});

  final String label;
  final double? value;
  final double? limit;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    final over = limit != null && v > limit!;
    final text = limit == null
        ? '$label ${XHelperFunctions.formatNumber(v, decimals: 0)} $unit'
        : '$label ${XHelperFunctions.formatNumber(v, decimals: 0)}/${XHelperFunctions.formatNumber(limit, decimals: 0)} $unit';
    return Semantics(
      label: over ? '$text, ${'above your daily limit'.tr}' : text,
      child: ExcludeSemantics(
        child: Chip(
          visualDensity: VisualDensity.compact,
          avatar: Icon(
            over ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 16,
            color: over ? XColors.error : XColors.success,
          ),
          label: Text(
            text,
            style: over ? const TextStyle(color: XColors.error, fontWeight: FontWeight.w600) : null,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arc, 0, 2 * math.pi, false, base);
    if (progress <= 0) return;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arc, -math.pi / 2, 2 * math.pi * progress.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}
