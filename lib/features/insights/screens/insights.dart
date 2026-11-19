import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../common/widgets/appbar/appbar.dart';
import '../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../common/widgets/texts/section_heading.dart';
import '../../../navigation_menu.dart';
import '../../../utils/constants/colors.dart';
import '../../../utils/constants/sizes.dart';
import '../../../utils/localization/translations.dart';
import '../../ai_agent/controllers/chat_controller.dart';
import '../../nutrition/controllers/food_diary_controller.dart';
import '../controllers/insights_controller.dart';
import '../models/insights_summary.dart';
import 'widgets/insight_sections.dart';
import 'widgets/metric_chart.dart';

/// -- Analytics of the logged food and water: 7, 14 or 30 days, compared with the period before.
/// Everything here is calculated from the user's own entries; AI suggestions are asked for separately.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  void _openDiary(DateTime day) {
    FoodDiaryController.instance.changeDate(day);
    NavigationController.instance.onDestinationSelected(1);
  }

  void _askAi(int days) {
    NavigationController.instance.onDestinationSelected(2);
    ChatController.instance.sendMessage('Analyze my nutrition over the last {days} days.'.trf({'days': days}));
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(InsightsController());
    final diary = FoodDiaryController.instance;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: XAppBar(title: Text('Insights'.tr)),
      body: Obx(() {
        final summary = controller.current.value;
        if (controller.loading.value && summary == null) return const Center(child: CircularProgressIndicator());
        if (summary == null) {
          return _Message(
            icon: Iconsax.cloud_cross,
            text: 'Insights could not be loaded.'.tr,
            button: 'Try again'.tr,
            onPressed: controller.load,
          );
        }
        final goals = diary.goals.value;
        final previous = controller.previous.value;
        final days = controller.periodDays.value;
        final metric = controller.metric.value;
        final selected = controller.selectedDay.value;
        final highlights = summary.highlights(goals, previous: previous);

        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// Period
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  segments: [
                    for (final p in InsightsController.periods)
                      ButtonSegment(value: p, label: Text('{days} days'.trf({'days': p}))),
                  ],
                  selected: {days},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => controller.setPeriod(s.first),
                ),
              ),
              if (controller.loading.value) const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: XSizes.spaceBtwItems),

              if (summary.isEmpty)
                _Message(
                  icon: Iconsax.chart_2,
                  text: 'Nothing logged in the last {days} days. Add your meals and water to see insights.'.trf({'days': days}),
                  button: 'Open food diary'.tr,
                  onPressed: () => NavigationController.instance.onDestinationSelected(1),
                )
              else ...[
                /// Summary numbers
                XInsightStats(summary: summary, goals: goals),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Daily chart for the chosen nutrient
                XSectionHeading(title: 'Day by day'.tr, showActionButton: false),
                const SizedBox(height: XSizes.sm),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: InsightMetric.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: XSizes.sm),
                    itemBuilder: (_, i) {
                      final m = InsightMetric.values[i];
                      return ChoiceChip(
                        label: Text(m.label),
                        selected: m == metric,
                        onSelected: (_) => controller.metric.value = m,
                      );
                    },
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwItems),
                XRoundedContainer(
                  child: XMetricChart(
                    summary: summary,
                    metric: metric,
                    goal: metric.goalOf(goals),
                    selectedDay: selected,
                    onDayTap: controller.selectDay,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: XSizes.xs),
                  child: Text('Tap a bar to see that day.'.tr, style: textTheme.labelSmall),
                ),
                if (selected != null) ...[
                  const SizedBox(height: XSizes.spaceBtwItems),
                  XSelectedDayCard(
                    summary: summary,
                    day: selected,
                    onOpenDiary: () => _openDiary(selected),
                    onClose: () => controller.selectDay(null),
                  ),
                ],
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Highlights
                if (highlights.isNotEmpty) ...[
                  XSectionHeading(title: 'Highlights'.tr, showActionButton: false),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  XHighlights(items: highlights),
                  const SizedBox(height: XSizes.spaceBtwSections),
                ],

                /// Averages vs previous period
                XSectionHeading(title: 'Daily averages'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                XAveragesCard(summary: summary, previous: previous, goals: goals),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Goals
                XSectionHeading(title: 'Goals reached'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                XGoalScorecard(summary: summary, goals: goals),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Macro balance
                XSectionHeading(title: 'Macro balance'.tr, showActionButton: false),
                const SizedBox(height: XSizes.spaceBtwItems),
                XMacroBalance(summary: summary),
                const SizedBox(height: XSizes.spaceBtwSections),

                /// Meals
                if (summary.loggedDays > 0) ...[
                  XSectionHeading(title: 'Meals'.tr, showActionButton: false),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  XMealPattern(summary: summary),
                  const SizedBox(height: XSizes.spaceBtwSections),

                  /// Foods
                  XSectionHeading(title: 'Foods'.tr, showActionButton: false),
                  const SizedBox(height: XSizes.spaceBtwItems),
                  XTopFoods(summary: summary),
                  const SizedBox(height: XSizes.spaceBtwSections),
                ],

                /// AI
                OutlinedButton.icon(
                  onPressed: () => _askAi(days),
                  icon: const Icon(Iconsax.magic_star),
                  label: Text('Ask the AI agent about these {days} days'.trf({'days': days})),
                ),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],

              Text(
                'Calculated from the food and water you logged. Averages use only the days with data, and nutrition values are estimates. This is not medical advice.'
                    .tr,
                style: textTheme.labelSmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.button, required this.onPressed});

  final IconData icon;
  final String text;
  final String button;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: XSizes.xl),
      child: Column(
        children: [
          Icon(icon, size: 56, color: XColors.darkGrey),
          const SizedBox(height: XSizes.spaceBtwItems),
          Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: XSizes.spaceBtwItems),
          ElevatedButton(onPressed: onPressed, child: Text(button)),
        ],
      ),
    );
  }
}
