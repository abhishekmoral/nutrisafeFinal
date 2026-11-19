import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/enums.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../controllers/food_diary_controller.dart';
import '../../../models/meal_entry_model.dart';
import '../../add_food/add_food.dart';
import '../../../../../utils/localization/translations.dart';
import 'entry_details_sheet.dart';

/// -- One meal (Breakfast, Lunch ...) with its entries.
/// Tap an entry for details and actions; swipe it left to remove (with Undo).
/// An empty meal offers to copy the same meal from the day before.
class XMealSection extends StatelessWidget {
  const XMealSection({super.key, required this.date, required this.mealType, this.readOnly = false});

  final DateTime date;
  final MealType mealType;
  final bool readOnly;

  static const _icons = {
    MealType.breakfast: Iconsax.coffee,
    MealType.lunch: Iconsax.sun_1,
    MealType.dinner: Iconsax.moon,
    MealType.snack: Iconsax.cake,
  };

  static String _n(double? v) => XHelperFunctions.formatNumber(v ?? 0, decimals: 0);

  Future<void> _remove(BuildContext context, MealEntryModel entry) async {
    final controller = FoodDiaryController.instance;
    final messenger = ScaffoldMessenger.of(context);
    controller.hideEntry(entry); // a dismissed row must leave the list at once
    await controller.deleteEntry(entry);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('{foodName} removed'.trf({'foodName': entry.foodName})),
          action: SnackBarAction(label: 'Undo'.tr, onPressed: () => controller.undoDelete(entry)),
        ),
      );
  }

  Future<void> _copyFromYesterday(List<MealEntryModel> previous) async {
    final saved = await FoodDiaryController.instance.copyEntries(previous, date, meal: mealType);
    if (saved > 0) {
      Get.closeCurrentSnackbar();
      Get.snackbar(
        'Copied {count} item(s)'.trf({'count': saved}),
        'Check the amounts if today was different.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(XSizes.md),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = FoodDiaryController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final entries = controller.entriesFor(date, mealType);
      final totals = controller.totalsFor(date, mealType);
      final previousDay = DateTime(date.year, date.month, date.day - 1);
      final previous = controller.entriesFor(previousDay, mealType);

      return XRoundedContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Heading
            Row(
              children: [
                Icon(_icons[mealType], color: XColors.primary),
                const SizedBox(width: XSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mealType.label, style: textTheme.titleLarge),
                      if (entries.isNotEmpty)
                        Text(
                          'P {p} g · C {c} g · F {f} g'.trf({'p': _n(totals.proteinG), 'c': _n(totals.carbsG), 'f': _n(totals.fatG)}),
                          style: textTheme.labelSmall,
                        ),
                    ],
                  ),
                ),
                if (entries.isNotEmpty) Text('${_n(totals.calories)} kcal', style: textTheme.titleSmall),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Add food to {label}'.trf({'label': mealType.label}),
                    onPressed: () => Get.to(() => AddFoodScreen(mealType: mealType, date: date)),
                    icon: const Icon(Iconsax.add_circle, color: XColors.primary),
                  ),
              ],
            ),

            /// Entries
            if (entries.isEmpty) ...[
              Text('Nothing logged yet'.tr, style: textTheme.labelMedium),
              if (!readOnly && previous.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _copyFromYesterday(previous),
                    icon: const Icon(Iconsax.copy, size: 18),
                    label: Text(
                      'Copy from {day} ({count} item(s))'.trf({
                        'day': XHelperFunctions.dayLabel(previousDay),
                        'count': previous.length,
                      }),
                    ),
                  ),
                ),
            ] else
              ...entries.map((entry) {
                final tile = ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onTap: readOnly ? null : () => XEntryDetailsSheet.show(context, entry),
                  title: Text(entry.foodName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    [
                      entry.quantityLabel,
                      if (entry.nutrition.proteinG != null)
                        'P {value} g'.trf({'value': XHelperFunctions.formatNumber(entry.nutrition.proteinG)}),
                      entry.quality.label,
                    ].join(' · '),
                  ),
                  trailing: Text(
                    entry.nutrition.calories == null ? '– kcal' : '${_n(entry.nutrition.calories)} kcal',
                    style: textTheme.bodyMedium,
                  ),
                );
                if (readOnly || entry.id == null) return tile;
                return Dismissible(
                  key: ValueKey(entry.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: XSizes.md),
                    decoration: BoxDecoration(color: XColors.error, borderRadius: BorderRadius.circular(XSizes.cardRadiusSm)),
                    child: const Icon(Iconsax.trash, color: XColors.white),
                  ),
                  onDismissed: (_) => _remove(context, entry),
                  child: tile,
                );
              }),
            if (!readOnly && entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: XSizes.xs),
                child: Text('Tap a food for details · swipe left to remove'.tr, style: textTheme.labelSmall),
              ),
          ],
        ),
      );
    });
  }
}
