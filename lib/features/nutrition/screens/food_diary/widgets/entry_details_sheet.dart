import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/enums.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../../utils/localization/translations.dart';
import '../../../../../utils/popups/loaders.dart';
import '../../../controllers/food_diary_controller.dart';
import '../../../models/meal_entry_model.dart';

/// -- Everything about one diary entry, with actions: change the amount, move to another meal,
/// add it again today, delete.
class XEntryDetailsSheet extends StatefulWidget {
  const XEntryDetailsSheet({super.key, required this.entry});

  final MealEntryModel entry;

  static Future<void> show(BuildContext context, MealEntryModel entry) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => XEntryDetailsSheet(entry: entry),
      );

  @override
  State<XEntryDetailsSheet> createState() => _XEntryDetailsSheetState();
}

class _XEntryDetailsSheetState extends State<XEntryDetailsSheet> {
  late final _quantity = TextEditingController(text: XHelperFunctions.formatNumber(widget.entry.quantity, decimals: 2));
  bool _busy = false;

  MealEntryModel get entry => widget.entry;

  static const _sources = {
    'manual': 'Entered manually',
    'barcode': 'Barcode scan',
    'label_ocr': 'Package label photo',
    'catalog': 'Food catalog',
    'ai_image': 'Food photo (AI)',
    'meal_plan': 'Meal plan',
    'voice': 'Voice',
    'ai_chat': 'AI chat',
  };

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action, String done) async {
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context);
      XLoaders.successSnackBar(title: done, message: entry.foodName);
    }
  }

  double? get _newQuantity {
    final v = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    return v == null || v <= 0 ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final controller = FoodDiaryController.instance;
    final textTheme = Theme.of(context).textTheme;
    final n = entry.nutrition;
    final isToday = DateUtils.isSameDay(entry.entryDate, DateTime.now());
    final factor = (_newQuantity ?? entry.quantity) / entry.quantity;
    String v(double? x, String unit) => x == null ? '–' : '${XHelperFunctions.formatNumber(x * factor, decimals: 1)} $unit';

    final rows = [
      ('Calories'.tr, v(n.calories, 'kcal')),
      ('Protein'.tr, v(n.proteinG, 'g')),
      ('Carbs'.tr, v(n.carbsG, 'g')),
      ('Fat'.tr, v(n.fatG, 'g')),
      ('Saturated fat'.tr, v(n.saturatedFatG, 'g')),
      ('Fiber'.tr, v(n.fiberG, 'g')),
      ('Sugar'.tr, v(n.sugarG, 'g')),
      ('Sodium'.tr, v(n.sodiumMg, 'mg')),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        XSizes.defaultSpace,
        0,
        XSizes.defaultSpace,
        MediaQuery.of(context).viewInsets.bottom + XSizes.defaultSpace,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(entry.foodName, style: textTheme.titleLarge),
            const SizedBox(height: XSizes.xs),
            Text(
              [
                entry.mealType.label,
                XHelperFunctions.dayLabel(entry.entryDate),
                (_sources[entry.entrySource] ?? entry.entrySource).tr,
                entry.quality.label,
              ].join(' · '),
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Amount
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                    decoration: InputDecoration(labelText: 'Amount'.tr, suffixText: entry.unit),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: XSizes.sm),
                FilledButton(
                  onPressed: _busy || _newQuantity == null || _newQuantity == entry.quantity
                      ? null
                      : () => _run(() => controller.changeQuantity(entry, _newQuantity!), 'Amount updated'.tr),
                  child: Text('Save'.tr),
                ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Nutrition for the amount in the box
            Wrap(
              spacing: XSizes.md,
              runSpacing: XSizes.xs,
              children: [
                for (final (label, value) in rows)
                  SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        Expanded(child: Text(label, style: textTheme.bodySmall)),
                        Text(value, style: textTheme.titleSmall),
                      ],
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: XSizes.xs),
              child: Text('"–" means the value is unknown, not zero.'.tr, style: textTheme.labelSmall),
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Move
            Text('Move to'.tr, style: textTheme.titleSmall),
            const SizedBox(height: XSizes.xs),
            Wrap(
              spacing: XSizes.sm,
              children: [
                for (final meal in MealType.values)
                  ChoiceChip(
                    label: Text(meal.label),
                    selected: meal == entry.mealType,
                    onSelected: _busy || meal == entry.mealType
                        ? null
                        : (_) => _run(
                              () => controller.moveEntry(entry, meal),
                              'Moved to {label}'.trf({'label': meal.label}),
                            ),
                  ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Other actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _run(
                              () async => await controller.copyEntries([entry], DateTime.now()) == 1,
                              isToday ? 'Added again'.tr : 'Copied to today'.tr,
                            ),
                    icon: const Icon(Iconsax.copy, size: 18),
                    label: Text(isToday ? 'Add again'.tr : 'Copy to today'.tr),
                  ),
                ),
                const SizedBox(width: XSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: XColors.error),
                    onPressed: _busy
                        ? null
                        : () async {
                            Navigator.pop(context);
                            await controller.deleteEntry(entry);
                            XLoaders.successSnackBar(title: 'Removed'.tr, message: entry.foodName);
                          },
                    icon: const Icon(Iconsax.trash, size: 18),
                    label: Text('Remove'.tr),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
