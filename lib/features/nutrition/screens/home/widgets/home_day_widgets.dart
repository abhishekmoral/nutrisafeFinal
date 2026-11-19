import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../../utils/constants/colors.dart';
import '../../../../../utils/constants/enums.dart';
import '../../../../../utils/constants/sizes.dart';
import '../../../../../utils/helpers/helper_function.dart';
import '../../../../../utils/localization/translations.dart';
import '../../../controllers/food_diary_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../models/meal_entry_model.dart';
import '../../add_food/add_food.dart';

/// -- "Lunch time: log your lunch" when the meal that fits the time of day is still empty.
class XHomeNextMeal extends StatelessWidget {
  const XHomeNextMeal({super.key});

  static const _icons = {
    MealType.breakfast: Iconsax.sun_1,
    MealType.lunch: Iconsax.sun,
    MealType.snack: Iconsax.coffee,
    MealType.dinner: Iconsax.moon,
  };

  @override
  Widget build(BuildContext context) {
    final diary = FoodDiaryController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final now = DateTime.now();
      final meal = HomeController.mealForTime(now);
      if (diary.entriesFor(now, meal).isNotEmpty) return const SizedBox.shrink();
      void open({bool scan = false}) =>
          Get.to(() => AddFoodScreen(mealType: meal, date: now, startWithScan: scan));
      return Padding(
        padding: const EdgeInsets.only(bottom: XSizes.spaceBtwItems),
        child: XRoundedContainer(
          showBorder: true,
          borderColor: XColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: XSizes.md, vertical: XSizes.sm),
          child: Row(
            children: [
              Icon(_icons[meal], color: XColors.primary),
              const SizedBox(width: XSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('{meal} not logged yet'.trf({'meal': meal.label}), style: textTheme.titleSmall),
                    Text('Add it now so today\'s totals stay right.'.tr, style: textTheme.labelSmall),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Scan a product'.tr,
                onPressed: () => open(scan: true),
                icon: const Icon(Iconsax.scan_barcode, color: XColors.primary),
              ),
              FilledButton(
                onPressed: open,
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                child: Text('Add'.tr),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// -- The last 7 days: a dot per day (filled = food logged) and the logging streak.
class XHomeWeekStrip extends StatelessWidget {
  const XHomeWeekStrip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final home = HomeController.instance;
    final diary = FoodDiaryController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      diary.entriesByDay.length; // rebuild when today's diary changes
      final logged = home.loggedIncludingToday();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final days = List.generate(7, (i) => DateTime(today.year, today.month, today.day - 6 + i));
      final streak = HomeController.streak(logged, today);
      final count = days.where((d) => logged.contains(XHelperFunctions.toDbDate(d))).length;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(XSizes.cardRadiusLg),
        child: XRoundedContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Iconsax.flash_1, color: XColors.secondary, size: 20),
                  const SizedBox(width: XSizes.xs),
                  Expanded(
                    child: Text(
                      streak == 0
                          ? 'Start a logging streak today'.tr
                          : (streak == 1 ? '1 day logging streak'.tr : '{count} day logging streak'.trf({'count': streak})),
                      style: textTheme.titleSmall,
                    ),
                  ),
                  Text('{count}/7 days'.trf({'count': count}), style: textTheme.labelMedium),
                ],
              ),
              const SizedBox(height: XSizes.sm),
              Semantics(
                label: '{count} of the last 7 days logged'.trf({'count': count}),
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final d in days)
                        Column(
                          children: [
                            Text(DateFormat('E').format(d).substring(0, 1), style: textTheme.labelSmall),
                            const SizedBox(height: 4),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: logged.contains(XHelperFunctions.toDbDate(d)) ? XColors.primary : Colors.transparent,
                                border: Border.all(
                                  color: d == today ? XColors.primary : XColors.grey,
                                  width: d == today ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: logged.contains(XHelperFunctions.toDbDate(d))
                                    ? const Icon(Icons.check, size: 16, color: XColors.white)
                                    : Text('${d.day}', style: textTheme.labelSmall),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// -- Recently eaten foods: one tap adds the same amount again to the current meal.
class XHomeRecentFoods extends StatelessWidget {
  const XHomeRecentFoods({super.key});

  Future<void> _logAgain(BuildContext context, MealEntryModel food) async {
    final suggested = HomeController.mealForTime(DateTime.now());
    final meal = await showModalBottomSheet<MealType>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(XSizes.md, XSizes.md, XSizes.md, XSizes.xs),
              child: Text(
                'Add {food} ({amount}) again to'.trf({'food': food.foodName, 'amount': food.quantityLabel}),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final meal in MealType.values)
              ListTile(
                title: Text(meal.label),
                trailing: meal == suggested ? const Icon(Iconsax.tick_circle, color: XColors.primary) : null,
                onTap: () => Navigator.pop(context, meal),
              ),
          ],
        ),
      ),
    );
    if (meal != null) await HomeController.instance.logAgain(food, meal);
  }

  @override
  Widget build(BuildContext context) {
    final home = HomeController.instance;
    final textTheme = Theme.of(context).textTheme;
    return Obx(() {
      final foods = home.recentFoods;
      if (foods.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log again'.tr, style: textTheme.titleMedium),
          Text('Same food and amount as last time.'.tr, style: textTheme.labelSmall),
          const SizedBox(height: XSizes.sm),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: foods.length,
              separatorBuilder: (_, _) => const SizedBox(width: XSizes.sm),
              itemBuilder: (_, i) {
                final f = foods[i];
                final busy = home.relogging.value == f.foodName;
                return InkWell(
                  onTap: home.relogging.value != null ? null : () => _logAgain(context, f),
                  borderRadius: BorderRadius.circular(XSizes.cardRadiusMd),
                  child: XRoundedContainer(
                    radius: XSizes.cardRadiusMd,
                    showBorder: true,
                    padding: const EdgeInsets.symmetric(horizontal: XSizes.md, vertical: XSizes.sm),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        busy
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Iconsax.add_circle, size: 18, color: XColors.primary),
                        const SizedBox(width: XSizes.sm),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(f.foodName, style: textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                '${f.quantityLabel} · ${XHelperFunctions.formatNumber(f.nutrition.calories, decimals: 0)} kcal',
                                style: textTheme.labelSmall,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}
