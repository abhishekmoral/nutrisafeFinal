import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/validators/validation.dart';
import '../../../nutrition/models/meal_entry_model.dart';
import '../../../nutrition/screens/add_food/add_food.dart';
import '../../controllers/member_diary_controller.dart';
import '../../models/diary_subject.dart';
import '../member_details/widgets/nutrition_today_card.dart';
import '../../../../utils/localization/translations.dart';

/// -- A family member's own food diary (independent of mine).
class MemberDiaryScreen extends StatelessWidget {
  const MemberDiaryScreen({super.key, required this.subject});

  final DiarySubject subject;

  Future<void> _editQuantity(BuildContext context, MemberDiaryController controller, MealEntryModel entry) async {
    final field = TextEditingController(text: XHelperFunctions.formatNumber(entry.quantity, decimals: 2));
    final formKey = GlobalKey<FormState>();
    final quantity = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change amount of {foodName}'.trf({'foodName': entry.foodName})),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: field,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => XValidator.validatePositiveNumber('amount', v),
            decoration: InputDecoration(labelText: 'Amount ({unit})'.trf({'unit': entry.unit})),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, double.parse(field.text.trim()));
            },
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
    if (quantity != null) controller.changeQuantity(entry, quantity);
  }

  Future<void> _delete(BuildContext context, MemberDiaryController controller, MealEntryModel entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove this food?'.tr),
        content: Text('{foodName} ({quantityLabel}) will be removed from {name}\'s diary.'.trf({'foodName': entry.foodName, 'quantityLabel': entry.quantityLabel, 'name': subject.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Remove'.tr)),
        ],
      ),
    );
    if (ok == true) controller.delete(entry);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      MemberDiaryController(subject: subject),
      tag: subject.childId ?? subject.ownerId,
    );
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('{name}\'s food diary'.trf({'name': subject.name}), overflow: TextOverflow.ellipsis)),
      body: Obx(() {
        final date = controller.date.value;
        final isToday = XHelperFunctions.dayLabel(date) == 'Today';
        return RefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Previous day'.tr,
                    onPressed: () => controller.shiftDate(-1),
                    icon: const Icon(Iconsax.arrow_left_2),
                  ),
                  Text(XHelperFunctions.dayLabel(date), style: textTheme.titleLarge),
                  IconButton(
                    tooltip: 'Next day'.tr,
                    onPressed: isToday ? null : () => controller.shiftDate(1),
                    icon: const Icon(Iconsax.arrow_right_3),
                  ),
                ],
              ),
              if (!subject.canAdd && !subject.isManaged)
                Text(
                  'View only. {name} has not allowed you to add food.'.trf({'name': subject.name}),
                  style: textTheme.labelMedium,
                ),
              const SizedBox(height: XSizes.sm),

              if (controller.loading.value)
                const Padding(padding: EdgeInsets.all(XSizes.xl), child: Center(child: CircularProgressIndicator()))
              else ...[
                XNutritionTodayCard(values: controller.totals),
                const SizedBox(height: XSizes.spaceBtwItems),
                for (final meal in MealType.values) ...[
                  XRoundedContainer(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(meal.label, style: textTheme.titleLarge)),
                            if (subject.canAdd)
                              IconButton(
                                tooltip: 'Add food to {label} for {name}'.trf({'label': meal.label, 'name': subject.name}),
                                onPressed: () async {
                                  await Get.to(() => AddFoodScreen(mealType: meal, date: date, subject: subject));
                                  controller.load();
                                },
                                icon: const Icon(Iconsax.add_circle, color: XColors.primary),
                              ),
                          ],
                        ),
                        if (controller.entriesFor(meal).isEmpty)
                          Text('Nothing logged'.tr, style: textTheme.labelMedium),
                        for (final entry in controller.entriesFor(meal))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: subject.canEdit ? () => _editQuantity(context, controller, entry) : null,
                            title: Text(entry.foodName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              [
                                entry.quantityLabel,
                                if (entry.nutrition.calories != null)
                                  '${XHelperFunctions.formatNumber(entry.nutrition.calories, decimals: 0)} kcal',
                                entry.quality.label,
                              ].join(' · '),
                            ),
                            trailing: subject.canDelete
                                ? IconButton(
                                    tooltip: 'Remove {foodName}'.trf({'foodName': entry.foodName}),
                                    onPressed: () => _delete(context, controller, entry),
                                    icon: const Icon(Iconsax.trash),
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: XSizes.spaceBtwItems),
                ],
                Text(XTexts.estimateNote, style: textTheme.labelMedium),
              ],
            ],
          ),
        );
      }),
    );
  }
}
