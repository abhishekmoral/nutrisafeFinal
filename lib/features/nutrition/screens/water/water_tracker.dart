import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/validators/validation.dart';
import '../../controllers/food_diary_controller.dart';
import '../../controllers/water_controller.dart';
import '../../models/nutrition_goal_model.dart';
import '../../../../utils/localization/translations.dart';

class WaterTrackerScreen extends StatelessWidget {
  const WaterTrackerScreen({super.key});

  /// Ask for a number (custom amount or the daily target).
  Future<int?> _askAmount(BuildContext context, String title, {String initial = ''}) async {
    final formKey = GlobalKey<FormState>();
    final field = TextEditingController(text: initial);
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            validator: (v) => XValidator.validateOptionalRange('Amount'.tr, v, 1, 10000),
            decoration: InputDecoration(labelText: 'Amount (ml)'.tr),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context, int.tryParse(field.text.trim()));
            },
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    return result;
  }

  Future<void> _changeTarget(BuildContext context) async {
    final diary = FoodDiaryController.instance;
    final current = diary.goals.value;
    final amount = await _askAmount(
      context,
      'Daily water target'.tr,
      initial: current?.waterMl?.toStringAsFixed(0) ?? '',
    );
    if (amount == null) return;
    await diary.saveGoals(
      NutritionGoalModel(
        calories: current?.calories,
        proteinG: current?.proteinG,
        carbsG: current?.carbsG,
        fatG: current?.fatG,
        fiberG: current?.fiberG,
        sugarG: current?.sugarG,
        sodiumMg: current?.sodiumMg,
        waterMl: amount.toDouble(),
        isCustom: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = WaterController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Water'.tr)),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: Obx(() {
          final target = controller.targetMl;
          return ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// Today
              XRoundedContainer(
                backgroundColor: XColors.water.withValues(alpha: 0.12),
                child: Column(
                  children: [
                    const Icon(Iconsax.drop, size: 40, color: XColors.water),
                    const SizedBox(height: XSizes.sm),
                    Text('${controller.todayTotal} ml', style: textTheme.headlineLarge),
                    Text(
                      target == null
                          ? 'No daily target set'.tr
                          : 'of your {value} ml target'.trf({'value': target.toStringAsFixed(0)}),
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: XSizes.spaceBtwItems),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: controller.progress,
                        minHeight: 10,
                        color: XColors.water,
                        backgroundColor: XColors.water.withValues(alpha: 0.2),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _changeTarget(context),
                      child: Text(target == null ? 'Set a target'.tr : 'Change target'.tr),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Quick add
              XSectionHeading(title: 'Add water'.tr, showActionButton: false),
              const SizedBox(height: XSizes.spaceBtwItems),
              Wrap(
                spacing: XSizes.sm,
                runSpacing: XSizes.sm,
                children: [
                  for (final amount in WaterController.quickAmounts)
                    ActionChip(
                      avatar: const Icon(Iconsax.add, size: XSizes.iconSm),
                      label: Text('$amount ml'),
                      onPressed: () => controller.addWater(amount),
                    ),
                  ActionChip(
                    avatar: const Icon(Iconsax.edit_2, size: XSizes.iconSm),
                    label: Text('Custom'.tr),
                    onPressed: () async {
                      final amount = await _askAmount(context, 'Add water'.tr);
                      if (amount != null) controller.addWater(amount);
                    },
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Last 7 days
              XSectionHeading(title: 'Last 7 days'.tr, showActionButton: false),
              const SizedBox(height: XSizes.spaceBtwItems),
              _WeekBars(totals: controller.weekTotals, target: target),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Today's logs
              XSectionHeading(title: 'Today\'s entries'.tr, showActionButton: false),
              if (controller.todayLogs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: XSizes.sm),
                  child: Text('No water logged today'.tr, style: textTheme.labelMedium),
                )
              else
                ...controller.todayLogs.map(
                  (log) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Iconsax.drop, color: XColors.water),
                    title: Text('${log['amount_ml']} ml'),
                    subtitle: Text(
                      DateFormat('h:mm a').format(DateTime.parse(log['logged_at']).toLocal()),
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove entry'.tr,
                      onPressed: () => controller.deleteLog(log['id'] as String),
                      icon: const Icon(Iconsax.trash),
                    ),
                  ),
                ),
              const SizedBox(height: XSizes.spaceBtwItems),
              Text(
                'Water needs differ from person to person. Set the target that suits you; if you have a kidney or heart condition, follow your doctor\'s advice on fluids.'.tr,
                style: textTheme.labelMedium,
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// -- Simple bar chart of daily totals.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.totals, required this.target});

  final Map<String, int> totals;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
    final values = days.map((d) => totals[XHelperFunctions.toDbDate(d)] ?? 0).toList();
    final maxValue = [...values, (target ?? 0).round(), 1].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Semantics(
                label: '{day}: {value} millilitres'.trf({'day': DateFormat('EEEE').format(days[i]), 'value': values[i]}),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        values[i] == 0 ? '' : (values[i] / 1000).toStringAsFixed(1),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 100 * values[i] / maxValue + 2,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: XColors.water,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('E').format(days[i]),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
