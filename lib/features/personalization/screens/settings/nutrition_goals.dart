import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/nutrition_calculator.dart';
import '../../../../utils/popups/loaders.dart';
import '../../../../utils/validators/validation.dart';
import '../../../nutrition/controllers/food_diary_controller.dart';
import '../../../nutrition/models/nutrition_goal_model.dart';
import '../../controllers/user_controller.dart';

/// -- The user's own daily targets. They are adjustable goals, not medical prescriptions.
class NutritionGoalsScreen extends StatefulWidget {
  const NutritionGoalsScreen({super.key});

  @override
  State<NutritionGoalsScreen> createState() => _NutritionGoalsScreenState();
}

class _NutritionGoalsScreenState extends State<NutritionGoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();
  final _sodium = TextEditingController();
  final _water = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fill(FoodDiaryController.instance.goals.value);
  }

  void _fill(NutritionGoalModel? goals) {
    String text(double? v) => v == null ? '' : v.toStringAsFixed(0);
    _calories.text = text(goals?.calories);
    _protein.text = text(goals?.proteinG);
    _carbs.text = text(goals?.carbsG);
    _fat.text = text(goals?.fatG);
    _fiber.text = text(goals?.fiberG);
    _sodium.text = text(goals?.sodiumMg);
    _water.text = text(goals?.waterMl);
  }

  @override
  void dispose() {
    for (final c in [_calories, _protein, _carbs, _fat, _fiber, _sodium, _water]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _value(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await FoodDiaryController.instance.saveGoals(
      NutritionGoalModel(
        calories: _value(_calories),
        proteinG: _value(_protein),
        carbsG: _value(_carbs),
        fatG: _value(_fat),
        fiberG: _value(_fiber),
        sugarG: FoodDiaryController.instance.goals.value?.sugarG,
        sodiumMg: _value(_sodium),
        waterMl: _value(_water),
        isCustom: true,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      Get.back();
      XLoaders.successSnackBar(title: 'Goals saved'.tr);
    }
  }

  Widget _field(String label, TextEditingController controller, double min, double max) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSizes.spaceBtwInputFields),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        validator: (v) => XValidator.validateOptionalRange(label, v, min, max),
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Daily nutrition goals'.tr)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'These are your personal targets. The suggested values are general estimates from your profile, not medical advice. Leave a field empty to not track it. If you have a medical condition, use the targets your doctor or dietitian gave you.'.tr,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: XSizes.spaceBtwItems),

              // Lower limit keeps very low calorie targets out.
              _field('Calories (kcal)'.tr, _calories, 1200, 6000),
              _field('Protein (g)'.tr, _protein, 10, 400),
              _field('Carbohydrates (g)'.tr, _carbs, 20, 900),
              _field('Fat (g)'.tr, _fat, 10, 300),
              _field('Fiber (g)'.tr, _fiber, 5, 100),
              _field('Sodium limit (mg)'.tr, _sodium, 500, 6000),
              _field('Water (ml)'.tr, _water, 500, 6000),

              /// Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...'.tr : 'Save goals'.tr),
                ),
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => setState(
                    () => _fill(XNutritionCalculator.suggestGoals(UserController.instance.user.value)),
                  ),
                  child: Text('Fill with suggested values'.tr),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
