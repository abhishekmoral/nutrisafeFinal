import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/validators/validation.dart';
import '../../controllers/add_food_controller.dart';
import '../../models/food_item_model.dart';
import '../../models/nutrition_values.dart';
import '../../../../utils/localization/translations.dart';

/// -- Type a food yourself. Nutrition fields are optional; empty = unknown (never guessed).
class ManualFoodEntryScreen extends StatefulWidget {
  const ManualFoodEntryScreen({super.key});

  @override
  State<ManualFoodEntryScreen> createState() => _ManualFoodEntryScreenState();
}

class _ManualFoodEntryScreenState extends State<ManualFoodEntryScreen> {
  static const _units = ['g', 'ml', 'piece', 'katori', 'cup', 'glass', 'tbsp', 'tsp', 'serving'];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sugar = TextEditingController();
  final _sodium = TextEditingController();
  String _unit = 'piece';

  @override
  void dispose() {
    for (final c in [_name, _quantity, _calories, _protein, _carbs, _fat, _fiber, _sugar, _sodium]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _value(TextEditingController controller) => double.tryParse(controller.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final nutrition = NutritionValues(
      calories: _value(_calories),
      proteinG: _value(_protein),
      carbsG: _value(_carbs),
      fatG: _value(_fat),
      fiberG: _value(_fiber),
      sugarG: _value(_sugar),
      sodiumMg: _value(_sodium),
    );
    final saved = await AddFoodController.instance.saveEntry(
      food: FoodItemModel(name: _name.text.trim(), entrySource: 'manual'),
      quantity: double.parse(_quantity.text.trim()),
      unit: _unit,
      nutrition: nutrition,
      quality: nutrition.isEmpty ? NutritionQuality.unknown : NutritionQuality.userEntered,
    );
    if (saved) Get.back(result: true);
  }

  Widget _nutrient(String label, TextEditingController controller, double max) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) => XValidator.validateOptionalRange(label, v, 0, max),
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AddFoodController.instance;
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Enter food manually'.tr)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Food name
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => XValidator.validateEmptyText('Food name'.tr, v),
                decoration: InputDecoration(labelText: 'Food name'.tr),
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),

              /// Quantity & unit
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => XValidator.validatePositiveNumber('quantity', v),
                      decoration: InputDecoration(labelText: 'Quantity'.tr),
                    ),
                  ),
                  const SizedBox(width: XSizes.spaceBtwInputFields),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _unit,
                      decoration: InputDecoration(labelText: 'Unit'.tr),
                      items: _units
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (value) => setState(() => _unit = value ?? _unit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Nutrition (optional)
              XSectionHeading(
                title: 'Nutrition for this quantity'.tr,
                showActionButton: false,
              ),
              Text(
                'Optional. Copy from the label if you have it. Leave a field empty when you do not know the value.'.tr,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _nutrient('Calories (kcal)'.tr, _calories, 10000)),
                  const SizedBox(width: XSizes.spaceBtwInputFields),
                  Expanded(child: _nutrient('Protein (g)'.tr, _protein, 1000)),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _nutrient('Carbs (g)'.tr, _carbs, 2000)),
                  const SizedBox(width: XSizes.spaceBtwInputFields),
                  Expanded(child: _nutrient('Fat (g)'.tr, _fat, 1000)),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _nutrient('Fiber (g)'.tr, _fiber, 500)),
                  const SizedBox(width: XSizes.spaceBtwInputFields),
                  Expanded(child: _nutrient('Sugar (g)'.tr, _sugar, 1000)),
                ],
              ),
              const SizedBox(height: XSizes.spaceBtwInputFields),
              _nutrient('Sodium (mg)'.tr, _sodium, 100000),
              const SizedBox(height: XSizes.spaceBtwSections),

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
