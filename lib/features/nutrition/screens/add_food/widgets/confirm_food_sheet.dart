import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/enums.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/constants/text_strings.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../../utils/helpers/nutrition_calculator.dart';
import '../../../../../utils/validators/validation.dart';
import '../../../controllers/add_food_controller.dart';
import '../../../models/food_item_model.dart';
import '../../../models/nutrition_values.dart';
import '../../../../../utils/localization/translations.dart';

/// -- The user confirms how much they actually ate before anything is saved.
class XConfirmFoodSheet extends StatefulWidget {
  const XConfirmFoodSheet({super.key, required this.food});

  final FoodItemModel food;

  @override
  State<XConfirmFoodSheet> createState() => _XConfirmFoodSheetState();
}

class _XConfirmFoodSheetState extends State<XConfirmFoodSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  late String _unit;

  FoodItemModel get food => widget.food;

  @override
  void initState() {
    super.initState();
    final units = food.availableUnits;
    // Prefer a household unit (piece, katori ...) when the food has one.
    _unit = food.unitWeights.isNotEmpty ? food.unitWeights.keys.first : units.first;
    _quantity.text = (_unit == 'g' || _unit == 'ml')
        ? XHelperFunctions.formatNumber(food.servingSize ?? 100)
        : '1';
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  NutritionValues? get _preview {
    final quantity = double.tryParse(_quantity.text.trim());
    if (quantity == null || quantity <= 0) return null;
    return XNutritionCalculator.forQuantity(food, quantity, _unit);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = AddFoodController.instance;
    final nutrition = _preview;
    final saved = await controller.saveEntry(
      food: food,
      quantity: double.parse(_quantity.text.trim()),
      unit: _unit,
      nutrition: nutrition ?? NutritionValues.empty,
      quality: nutrition == null || nutrition.isEmpty
          ? NutritionQuality.unknown
          : (food.quality == NutritionQuality.verified
                ? NutritionQuality.calculated
                : NutritionQuality.estimated),
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AddFoodController.instance;
    final textTheme = Theme.of(context).textTheme;
    final allergenMatches = controller.matchingAllergens(food);
    final preview = _preview;

    return Padding(
      padding: EdgeInsets.only(
        left: XSizes.defaultSpace,
        right: XSizes.defaultSpace,
        bottom: MediaQuery.of(context).viewInsets.bottom + XSizes.defaultSpace,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Food name
              Text(food.name, style: textTheme.headlineSmall),
              Text(
                [
                  if (food.brand != null && food.brand!.isNotEmpty) food.brand!,
                  'Nutrition data: {label}'.trf({'label': food.quality.label}),
                  if (food.source != null && food.source!.isNotEmpty) 'Source: {source}'.trf({'source': food.source}),
                ].join(' · '),
                style: textTheme.labelMedium,
              ),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Allergen warning
              if (allergenMatches.isNotEmpty) ...[
                XRoundedContainer(
                  backgroundColor: XColors.error.withValues(alpha: 0.12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Iconsax.warning_2, color: XColors.error),
                      const SizedBox(width: XSizes.sm),
                      Expanded(
                        child: Text(
                          'May contain {owner}: {allergens}. Please check the label before eating.'.trf({
                            'owner': controller.allergenOwnerLabel,
                            'allergens': allergenMatches.map((a) => a.tr).join(', '),
                          }),
                          style: textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],
              if (controller.userAllergens.isNotEmpty && allergenMatches.isEmpty) ...[
                Text(XTexts.allergyDisclaimer, style: textTheme.labelMedium),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],

              /// Quantity & unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _quantity,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => XValidator.validatePositiveNumber('quantity', v),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: 'How much did you eat?'.tr),
                    ),
                  ),
                  const SizedBox(width: XSizes.spaceBtwItems),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Unit'.tr),
                      items: food.availableUnits
                          .map(
                            (u) => DropdownMenuItem(
                              value: u,
                              child: Text(FoodItemModel.unitLabel(u), overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _unit = value ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Nutrition preview
              XRoundedContainer(
                width: double.infinity,
                child: preview == null || preview.isEmpty
                    ? Text(
                        'Nutrition for this food is unknown. It will be saved without values and will not count towards your totals.'.tr,
                        style: textTheme.bodyMedium,
                      )
                    : Wrap(
                        spacing: XSizes.lg,
                        runSpacing: XSizes.sm,
                        children: [
                          _Value('Calories'.tr, preview.calories, 'kcal'),
                          _Value('Protein'.tr, preview.proteinG, 'g'),
                          _Value('Carbs'.tr, preview.carbsG, 'g'),
                          _Value('Fat'.tr, preview.fatG, 'g'),
                          _Value('Fiber'.tr, preview.fiberG, 'g'),
                          _Value('Sugar'.tr, preview.sugarG, 'g'),
                          _Value('Sodium'.tr, preview.sodiumMg, 'mg'),
                        ],
                      ),
              ),
              const SizedBox(height: XSizes.sm),
              Text(XTexts.estimateNote, style: textTheme.labelMedium),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Save
              SizedBox(
                width: double.infinity,
                child: Obx(
                  () => ElevatedButton(
                    onPressed: controller.saving.value ? null : _save,
                    child: Text(
                      controller.saving.value
                          ? 'Saving...'.tr
                          : 'Add to {label}'.trf({'label': controller.mealType.label}),
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

class _Value extends StatelessWidget {
  const _Value(this.label, this.value, this.unit);

  final String label;
  final double? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelMedium),
        Text(
          value == null ? '–' : '${XHelperFunctions.formatNumber(value)} $unit',
          style: textTheme.titleLarge,
        ),
      ],
    );
  }
}
