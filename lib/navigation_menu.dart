import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import 'features/ai_agent/controllers/chat_controller.dart';
import 'features/ai_agent/screens/chat/chat.dart';
import 'features/family/controllers/family_controller.dart';
import 'features/insights/controllers/insights_controller.dart';
import 'features/insights/screens/insights.dart';
import 'features/nutrition/controllers/food_diary_controller.dart';
import 'features/nutrition/controllers/water_controller.dart';
import 'features/nutrition/controllers/home_controller.dart';
import 'features/nutrition/screens/food_diary/food_diary.dart';
import 'features/nutrition/screens/home/home.dart';
import 'features/personalization/screens/profile/profile.dart';
import 'utils/constants/colors.dart';
import 'utils/helpers/helper_function.dart';

class NavigationMenu extends StatelessWidget {
  const NavigationMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());
    final dark = XHelperFunctions.isDarkMode(context);

    return Scaffold(
      /// Bottom Navigation Bar
      bottomNavigationBar: Obx(
        () => NavigationBar(
          height: 76,
          elevation: 0,
          selectedIndex: controller.selectedIndex.value,
          onDestinationSelected: controller.onDestinationSelected,
          backgroundColor: dark ? XColors.darkBackground : XColors.white,
          indicatorColor: XColors.primary.withValues(alpha: 0.18),
          destinations: [
            /// Home
            NavigationDestination(
              icon: Icon(Iconsax.home),
              selectedIcon: Icon(Iconsax.home_15),
              label: 'Home'.tr,
            ),

            /// Food
            NavigationDestination(
              icon: Icon(Iconsax.reserve),
              selectedIcon: Icon(Iconsax.reserve5),
              label: 'Food'.tr,
            ),

            /// AI Agent
            NavigationDestination(
              icon: Icon(Iconsax.magic_star),
              selectedIcon: Icon(Iconsax.magic_star5),
              label: 'AI Agent'.tr,
            ),

            /// Insights
            NavigationDestination(
              icon: Icon(Iconsax.chart_2),
              selectedIcon: Icon(Iconsax.chart_215),
              label: 'Insights'.tr,
            ),

            /// Profile
            NavigationDestination(
              icon: Icon(Iconsax.user),
              selectedIcon: Icon(Iconsax.user_tick),
              label: 'Profile'.tr,
            ),
          ],
        ),
      ),

      /// Screen Content
      body: Obx(() => controller.screens[controller.selectedIndex.value]),
    );
  }
}

class NavigationController extends GetxController {
  static NavigationController get instance => Get.find();

  RxInt selectedIndex = 0.obs;

  final screens = const [
    /// Home Screen
    HomeScreen(),

    /// Food Diary Screen
    FoodDiaryScreen(),

    /// AI Agent Screen
    ChatScreen(),

    /// Insights Screen
    InsightsScreen(),

    /// Profile Screen
    ProfileScreen(),
  ];

  @override
  void onInit() {
    super.onInit();
    // Controllers shared between tabs live as long as the signed-in area does.
    Get.put(FoodDiaryController());
    Get.put(WaterController());
    Get.put(ChatController());
    Get.put(FamilyController()); // Home shows the family; the Family screens reuse it.
    HomeController.instance; // week strip and "log again" on Home
  }

  void onDestinationSelected(int index) {
    selectedIndex.value = index;
    // Insights are recalculated each time the tab is opened.
    if (index == 3 && Get.isRegistered<InsightsController>()) InsightsController.instance.load();
  }
}
