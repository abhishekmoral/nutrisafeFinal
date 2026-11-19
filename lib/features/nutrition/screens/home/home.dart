import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../navigation_menu.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../family/controllers/family_controller.dart';
import '../../controllers/food_diary_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/water_controller.dart';
import '../food_diary/widgets/meal_section.dart';
import 'widgets/home_day_widgets.dart';
import 'widgets/home_family.dart';
import 'widgets/home_header.dart';
import 'widgets/home_insights.dart';
import 'widgets/home_quick_actions.dart';
import 'widgets/home_today_card.dart';
import 'widgets/home_water_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => Future.wait([
            FoodDiaryController.instance.refreshAll(),
            WaterController.instance.load(),
            FamilyController.instance.load(),
            HomeController.instance.load(),
          ]),
          child: ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// Header
              const XHomeHeader(),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Today at a glance
              const XHomeTodayCard(),
              const SizedBox(height: XSizes.spaceBtwItems),
              const XHomeNextMeal(),
              const XHomeWaterCard(),
              const SizedBox(height: XSizes.spaceBtwItems),
              XHomeWeekStrip(onTap: () => NavigationController.instance.onDestinationSelected(3)),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Family members already added
              const XHomeFamily(),

              /// Quick Actions
              XSectionHeading(title: 'Quick actions'.tr, showActionButton: false),
              const SizedBox(height: XSizes.spaceBtwItems),
              const XHomeQuickActions(),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Foods eaten recently, one tap to add again
              const XHomeRecentFoods(),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Insights
              XSectionHeading(
                title: 'Insights'.tr,
                buttonTitle: 'See all'.tr,
                onPressed: () => NavigationController.instance.onDestinationSelected(3),
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              const XHomeInsights(),
              const SizedBox(height: XSizes.spaceBtwSections),

              /// Daily Food Summary
              XSectionHeading(
                title: 'Today\'s meals'.tr,
                buttonTitle: 'Open diary'.tr,
                onPressed: () => NavigationController.instance.onDestinationSelected(1),
              ),
              const SizedBox(height: XSizes.spaceBtwItems),
              for (final meal in MealType.values) ...[
                XMealSection(date: DateTime.now(), mealType: meal),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
