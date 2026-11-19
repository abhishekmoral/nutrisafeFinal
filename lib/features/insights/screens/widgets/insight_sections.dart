import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/progress/nutrient_progress.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/localization/translations.dart';
import '../../../nutrition/models/nutrition_goal_model.dart';
import '../../models/insights_summary.dart';

String _n(double? v, {int decimals = 0}) => XHelperFunctions.formatNumber(v, decimals: decimals);

/// -- Three numbers at the top: days logged, streak, average calories.
class XInsightStats extends StatelessWidget {
  const XInsightStats({super.key, required this.summary, required this.goals});

  final InsightsSummary summary;
  final NutritionGoalModel? goals;

  @override
  Widget build(BuildContext context) {
    final streak = summary.streak(DateTime.now());
    final calories = summary.average(InsightMetric.calories);
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Iconsax.calendar_tick,
            color: XColors.primary,
            value: '${summary.loggedDays}/${summary.periodLength}',
            label: 'days logged'.tr,
          ),
        ),
        const SizedBox(width: XSizes.sm),
        Expanded(
          child: _StatTile(
            icon: Iconsax.flash_1,
            color: XColors.secondary,
            value: '$streak',
            label: streak == 1 ? 'day streak'.tr : 'days streak'.tr,
          ),
        ),
        const SizedBox(width: XSizes.sm),
        Expanded(
          child: _StatTile(
            icon: Iconsax.chart_21,
            color: XColors.calories,
            value: calories == null ? '–' : _n(calories),
            label: 'avg kcal / day'.tr,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: XRoundedContainer(
          padding: const EdgeInsets.symmetric(vertical: XSizes.md, horizontal: XSizes.sm),
          backgroundColor: color.withValues(alpha: 0.12),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: XSizes.xs),
              FittedBox(child: Text(value, style: textTheme.headlineSmall)),
              Text(label, style: textTheme.labelSmall, textAlign: TextAlign.center, maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }
}

/// -- Details of the day tapped in the chart.
class XSelectedDayCard extends StatelessWidget {
  const XSelectedDayCard({super.key, required this.summary, required this.day, required this.onOpenDiary, required this.onClose});

  final InsightsSummary summary;
  final DateTime day;
  final VoidCallback onOpenDiary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final key = XHelperFunctions.toDbDate(day);
    final entries = summary.entries.where((e) => XHelperFunctions.toDbDate(e.entryDate) == key).toList();
    final water = summary.valueOn(InsightMetric.water, day);
    return XRoundedContainer(
      showBorder: true,
      borderColor: XColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(DateFormat('EEEE, d MMM').format(day), style: textTheme.titleMedium)),
              IconButton(onPressed: onClose, icon: const Icon(Icons.close), tooltip: 'Close'.tr, visualDensity: VisualDensity.compact),
            ],
          ),
          if (entries.isEmpty && water == null)
            Text('Nothing logged on this day.'.tr, style: textTheme.bodyMedium)
          else ...[
            Wrap(
              spacing: XSizes.md,
              runSpacing: XSizes.xs,
              children: [
                for (final m in InsightMetric.values)
                  if (summary.valueOn(m, day) != null)
                    Text('${m.label}: ${_n(summary.valueOn(m, day))} ${m.unit}', style: textTheme.bodySmall),
              ],
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: XSizes.sm),
              Text(
                entries.length == 1 ? '1 item logged'.tr : '{count} items logged'.trf({'count': entries.length}),
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: XSizes.xs),
              ...entries.take(6).map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 70, child: Text(e.mealType.label, style: textTheme.labelSmall)),
                          Expanded(child: Text(e.foodName, style: textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
                          Text(e.nutrition.calories == null ? '–' : '${_n(e.nutrition.calories)} kcal', style: textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
              if (entries.length > 6)
                Text('and {count} more'.trf({'count': entries.length - 6}), style: textTheme.labelSmall),
            ],
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpenDiary,
              icon: const Icon(Iconsax.book_1, size: 18),
              label: Text('Open in diary'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

/// -- Average per day for each nutrient, with the change against the previous period.
class XAveragesCard extends StatelessWidget {
  const XAveragesCard({super.key, required this.summary, required this.previous, required this.goals});

  final InsightsSummary summary;
  final InsightsSummary? previous;
  final NutritionGoalModel? goals;

  @override
  Widget build(BuildContext context) {
    return XRoundedContainer(
      child: Column(
        children: [
          for (final m in InsightMetric.values) ...[
            XNutrientProgress(
              label: m.label,
              value: summary.average(m),
              goal: m.goalOf(goals),
              unit: m.unit,
              color: m.isLimit && (summary.average(m) ?? 0) > (m.goalOf(goals) ?? double.infinity) ? XColors.error : m.color,
            ),
            _ChangeLine(metric: m, now: summary.average(m), before: previous?.average(m), days: summary.periodLength),
            if (m != InsightMetric.values.last) const SizedBox(height: XSizes.spaceBtwItems),
          ],
        ],
      ),
    );
  }
}

class _ChangeLine extends StatelessWidget {
  const _ChangeLine({required this.metric, required this.now, required this.before, required this.days});

  final InsightMetric metric;
  final double? now;
  final double? before;
  final int days;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final change = InsightsSummary.change(now, before);
    if (change == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(now == null ? 'Not logged in this period'.tr : 'No data for the previous {days} days'.trf({'days': days}), style: style),
        ),
      );
    }
    final up = change > 0;
    final flat = change.abs() < 3;
    // Up is good for protein, fiber and water; down is good for limits (sugar, sodium); others are neutral.
    final good = metric.isLimit ? !up : (metric == InsightMetric.protein || metric == InsightMetric.fiber || metric == InsightMetric.water) ? up : null;
    final color = flat || good == null ? XColors.darkGrey : (good ? XColors.success : XColors.warning);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(flat ? Iconsax.minus : (up ? Iconsax.arrow_up_3 : Iconsax.arrow_down), size: 14, color: color),
          const SizedBox(width: 2),
          Text(
            flat
                ? 'About the same as the previous {days} days'.trf({'days': days})
                : '{percent}% vs previous {days} days'.trf({'percent': _n(change.abs()), 'days': days}),
            style: style!.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// -- For every goal the user set: on how many logged days it was met.
class XGoalScorecard extends StatelessWidget {
  const XGoalScorecard({super.key, required this.summary, required this.goals});

  final InsightsSummary summary;
  final NutritionGoalModel? goals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rows = [
      for (final m in InsightMetric.values)
        if (summary.goalDays(m, m.goalOf(goals)) case final g?) (m, g),
    ];
    if (rows.isEmpty) {
      return Text('Set nutrition goals in your profile to see how often you reach them.'.tr, style: textTheme.bodyMedium);
    }
    return XRoundedContainer(
      child: Column(
        children: [
          for (final (m, g) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: XSizes.xs),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: m.color, shape: BoxShape.circle)),
                  const SizedBox(width: XSizes.sm),
                  Expanded(
                    child: Text(
                      m.isLimit
                          ? '{nutrient}: within limit'.trf({'nutrient': m.label})
                          : (m.isTarget ? '{nutrient}: near goal (±10%)'.trf({'nutrient': m.label}) : '{nutrient}: goal reached'.trf({'nutrient': m.label})),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  // One dot per day with data.
                  ...List.generate(
                    g.of > 10 ? 0 : g.of,
                    (i) => Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Icon(
                        i < g.met ? Icons.circle : Icons.circle_outlined,
                        size: 10,
                        color: i < g.met ? XColors.success : XColors.darkGrey,
                      ),
                    ),
                  ),
                  const SizedBox(width: XSizes.sm),
                  Text('${g.met}/${g.of}', style: textTheme.titleSmall),
                ],
              ),
            ),
          const SizedBox(height: XSizes.xs),
          Text('Counted over the days that have a value logged.'.tr, style: textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// -- Share of calories from protein, carbs and fat.
class XMacroBalance extends StatelessWidget {
  const XMacroBalance({super.key, required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final split = summary.macroSplit;
    if (split == null) return Text('Log foods with nutrition values to see your macro balance.'.tr, style: textTheme.bodyMedium);
    final parts = [
      (InsightMetric.protein, split.protein),
      (InsightMetric.carbs, split.carbs),
      (InsightMetric.fat, split.fat),
    ];
    return XRoundedContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: parts.map((p) => '${p.$1.label} ${_n(p.$2 * 100)}%').join(', '),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Row(
                    children: [
                      for (final (m, share) in parts)
                        if (share > 0) Expanded(flex: (share * 1000).round().clamp(1, 1000), child: Container(color: m.color)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: XSizes.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (m, share) in parts)
                Column(
                  children: [
                    Text('${_n(share * 100)}%', style: textTheme.titleMedium!.copyWith(color: m.color)),
                    Text(m.label, style: textTheme.labelSmall),
                  ],
                ),
            ],
          ),
          const SizedBox(height: XSizes.sm),
          Text(
            'Share of calories from each, using 4 kcal per gram of protein and carbs and 9 kcal per gram of fat.'.tr,
            style: textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// -- How often each meal was logged and its average calories.
class XMealPattern extends StatelessWidget {
  const XMealPattern({super.key, required this.summary});

  final InsightsSummary summary;

  static const _icons = {
    MealType.breakfast: Iconsax.sun_1,
    MealType.lunch: Iconsax.sun,
    MealType.dinner: Iconsax.moon,
    MealType.snack: Iconsax.coffee,
  };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final logged = summary.loggedDays;
    return XRoundedContainer(
      child: Column(
        children: [
          for (final stat in summary.mealStats)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: XSizes.xs),
              child: Row(
                children: [
                  Icon(_icons[stat.meal], size: 20, color: XColors.primary),
                  const SizedBox(width: XSizes.sm),
                  SizedBox(width: 80, child: Text(stat.meal.label, style: textTheme.bodyMedium)),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: logged == 0 ? 0 : stat.daysLogged / logged,
                        minHeight: 6,
                        color: XColors.primary,
                        backgroundColor: XColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: XSizes.sm),
                  SizedBox(
                    width: 92,
                    child: Text(
                      '${stat.daysLogged}/$logged ${'days'.tr}\n${stat.averageCalories == null ? '–' : '~${_n(stat.averageCalories)} kcal'}',
                      textAlign: TextAlign.right,
                      style: textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// -- Most logged foods, and the foods that brought the most of a nutrient.
class XTopFoods extends StatelessWidget {
  const XTopFoods({super.key, required this.summary});

  final InsightsSummary summary;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top = summary.topFoods();
    final sections = [
      (InsightMetric.protein, 'Top protein sources'.tr),
      (InsightMetric.sodium, 'Top sodium sources'.tr),
      (InsightMetric.sugar, 'Top sugar sources'.tr),
    ];
    return XRoundedContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Logged most often'.tr, style: textTheme.titleSmall),
          const SizedBox(height: XSizes.xs),
          for (var i = 0; i < top.length; i++)
            _FoodRow(rank: i + 1, name: top[i].name, trailing: top[i].count == 1 ? '1 time'.tr : '{count} times'.trf({'count': top[i].count})),
          for (final (metric, title) in sections)
            if (summary.topSources(metric).isNotEmpty) ...[
              const SizedBox(height: XSizes.spaceBtwItems),
              Text(title, style: textTheme.titleSmall),
              const SizedBox(height: XSizes.xs),
              for (final (i, f) in summary.topSources(metric).indexed)
                _FoodRow(rank: i + 1, name: f.name, trailing: '${_n(f.amount)} ${metric.unit}', color: metric.color),
            ],
        ],
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.rank, required this.name, required this.trailing, this.color = XColors.primary});

  final int rank;
  final String name;
  final String trailing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text('$rank', style: textTheme.labelSmall!.copyWith(color: color)),
          ),
          const SizedBox(width: XSizes.sm),
          Expanded(child: Text(name, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
          Text(trailing, style: textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// -- Calculated facts about the period.
class XHighlights extends StatelessWidget {
  const XHighlights({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return XRoundedContainer(
      backgroundColor: XColors.primaryBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: XSizes.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Iconsax.lamp_on, size: 18, color: XColors.primaryDark),
                  const SizedBox(width: XSizes.sm),
                  Expanded(child: Text(item, style: textTheme.bodyMedium!.apply(color: XColors.textPrimary))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
