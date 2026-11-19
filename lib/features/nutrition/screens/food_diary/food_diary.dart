import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/constants/text_strings.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/localization/translations.dart';
import '../../controllers/food_diary_controller.dart';
import '../../controllers/home_controller.dart';
import '../add_food/add_food.dart';
import 'widgets/day_totals_card.dart';
import 'widgets/meal_section.dart';

class FoodDiaryScreen extends StatelessWidget {
  const FoodDiaryScreen({super.key});

  Future<void> _pickDate(BuildContext context, FoodDiaryController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDate.value,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) controller.changeDate(picked);
  }

  Future<void> _copyDayToToday(BuildContext context, FoodDiaryController controller, DateTime date) async {
    final entries = controller.entriesOn(date);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Copy this day to today?'.tr),
        content: Text(
          'All {count} item(s) from {day} will be added to today, in the same meals and amounts.'
              .trf({'count': entries.length, 'day': XHelperFunctions.dayLabel(date)}),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Copy'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    final saved = await controller.copyEntries(entries, DateTime.now());
    if (saved > 0) controller.changeDate(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final controller = FoodDiaryController.instance;
    return Scaffold(
      appBar: XAppBar(
        title: Text('Food Diary'.tr),
        actions: [
          IconButton(
            tooltip: 'Scan product'.tr,
            onPressed: () => Get.to(
              () => AddFoodScreen(
                mealType: HomeController.mealForTime(DateTime.now()),
                date: controller.selectedDate.value,
                startWithScan: true,
              ),
            ),
            icon: const Icon(Iconsax.scan_barcode),
          ),
          Obx(() {
            final date = controller.selectedDate.value;
            final isToday = DateUtils.isSameDay(date, DateTime.now());
            final hasEntries = controller.entriesOn(date).isNotEmpty;
            return PopupMenuButton<String>(
              tooltip: 'More'.tr,
              onSelected: (value) {
                if (value == 'copy') _copyDayToToday(context, controller, date);
                if (value == 'today') controller.changeDate(DateTime.now());
                if (value == 'pick') _pickDate(context, controller);
              },
              itemBuilder: (_) => [
                if (!isToday) PopupMenuItem(value: 'today', child: Text('Go to today'.tr)),
                PopupMenuItem(value: 'pick', child: Text('Pick a date'.tr)),
                if (!isToday && hasEntries) PopupMenuItem(value: 'copy', child: Text('Copy this day to today'.tr)),
              ],
            );
          }),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([controller.refreshAll(), HomeController.instance.load()]),
        child: Obx(() {
          final date = controller.selectedDate.value;
          final isToday = DateUtils.isSameDay(date, DateTime.now());
          return ListView(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            children: [
              /// Date
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? 'Today'.tr : DateFormat('EEEE, d MMM').format(date),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Pick a date'.tr,
                    onPressed: () => _pickDate(context, controller),
                    icon: const Icon(Iconsax.calendar_1),
                  ),
                ],
              ),
              _DayStrip(selected: date, onSelect: controller.changeDate),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Day totals
              XDayTotalsCard(date: date),
              const SizedBox(height: XSizes.spaceBtwItems),

              /// Meals
              for (final meal in MealType.values) ...[
                XMealSection(date: date, mealType: meal),
                const SizedBox(height: XSizes.spaceBtwItems),
              ],
              Text(XTexts.estimateNote, style: Theme.of(context).textTheme.labelMedium),
            ],
          );
        }),
      ),
    );
  }
}

/// -- The last 14 days in a row (newest on the right). A dot marks days with food logged.
class _DayStrip extends StatefulWidget {
  const _DayStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_DayStrip> createState() => _DayStripState();
}

class _DayStripState extends State<_DayStrip> {
  static const _days = 14;
  static const _itemWidth = 48.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Start at the newest days.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(_days, (i) => DateTime(today.year, today.month, today.day - (_days - 1) + i));
    return SizedBox(
      height: 66,
      child: Obx(() {
        final logged = HomeController.instance.loggedIncludingToday();
        return ListView.separated(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (_, i) {
            final d = days[i];
            final isSelected = DateUtils.isSameDay(d, widget.selected);
            final hasFood = logged.contains(XHelperFunctions.toDbDate(d));
            final fg = isSelected ? XColors.white : null;
            return Semantics(
              button: true,
              selected: isSelected,
              label: '${DateFormat('EEEE d MMMM').format(d)}${hasFood ? ', ${'food logged'.tr}' : ''}',
              child: ExcludeSemantics(
                child: InkWell(
                  onTap: () => widget.onSelect(d),
                  borderRadius: BorderRadius.circular(XSizes.cardRadiusMd),
                  child: Container(
                    width: _itemWidth,
                    decoration: BoxDecoration(
                      color: isSelected ? XColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(XSizes.cardRadiusMd),
                      border: Border.all(color: isSelected ? XColors.primary : XColors.grey),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('E').format(d), style: textTheme.labelSmall!.copyWith(color: fg)),
                        Text('${d.day}', style: textTheme.titleMedium!.copyWith(color: fg)),
                        const SizedBox(height: 2),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hasFood ? (isSelected ? XColors.white : XColors.primary) : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
