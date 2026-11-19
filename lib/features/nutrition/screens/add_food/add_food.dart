import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/enums.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/popups/loaders.dart';
import '../../../family/models/diary_subject.dart';
import '../../controllers/add_food_controller.dart';
import '../../../../utils/helpers/label_text_parser.dart';
import '../../models/food_item_model.dart';
import '../../models/product_draft.dart';
import '../../models/scanned_barcode.dart';
import 'barcode_scanner.dart';
import 'label_capture.dart';
import 'product_review.dart';
import 'manual_food_entry.dart';
import 'widgets/confirm_food_sheet.dart';
import 'widgets/food_result_tile.dart';
import '../../../../utils/localization/translations.dart';

class AddFoodScreen extends StatelessWidget {
  const AddFoodScreen({
    super.key,
    required this.mealType,
    required this.date,
    this.startWithScan = false,
    this.subject,
  });

  final MealType mealType;
  final DateTime date;
  final bool startWithScan;
  final DiarySubject? subject; // a family member's diary instead of my own

  /// Ask for the quantity, then save. Nothing is added without this confirmation.
  Future<void> _confirm(BuildContext context, FoodItemModel food) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => XConfirmFoodSheet(food: food),
    );
    if (saved == true) {
      Get.back();
      XLoaders.successSnackBar(title: 'Added to {label}'.trf({'label': mealType.label}), message: food.name);
    }
  }

  /// Scan → NutriSafe → Open Food Facts → other product databases → package label photos
  /// → check the details → save the product → quantity.
  Future<void> _scan(BuildContext context) async {
    final controller = AddFoodController.instance;
    final scan = await Get.to<ScannedBarcode>(() => const BarcodeScannerScreen());
    if (scan == null || !context.mounted) return;

    XLoaders.openLoadingDialog();
    var draft = await controller.lookupBarcode(scan);
    XLoaders.stopLoading();
    // null = the search could not run (no connection); the error was shown. Never "not found".
    if (draft == null || !context.mounted) return;

    // Already confirmed earlier (by this person, or checked against manufacturer data).
    if (draft.isSaved) {
      await _confirm(context, draft.toFoodItem());
      return;
    }

    // No database knows the barcode: read the package label.
    if (draft.isNotFound) {
      final label = await Get.to<LabelReadResult>(() => LabelCaptureScreen(providers: draft!.providers));
      if (label == null || !context.mounted) return;
      draft = draft.withMissingFrom(ProductDraft.fieldsFromLabel(label));
    }

    final food = await Get.to<FoodItemModel>(() => ProductReviewScreen(draft: draft!));
    if (food != null && context.mounted) await _confirm(context, food);
  }

  Future<void> _openManual() async {
    final saved = await Get.to<bool>(() => const ManualFoodEntryScreen());
    if (saved == true) {
      Get.back();
      XLoaders.successSnackBar(title: 'Added to {label}'.trf({'label': mealType.label}));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AddFoodController(mealType: mealType, date: date, subject: subject));
    if (startWithScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.scanOpened) {
          controller.scanOpened = true;
          _scan(context);
        }
      });
    }
    return Scaffold(
      appBar: XAppBar(
        showBackArrow: true,
        title: Text(
          subject == null
              ? 'Add to {label} · {day}'.trf({'label': mealType.label, 'day': XHelperFunctions.dayLabel(date)})
              : '${subject!.name} · ${mealType.label} · ${XHelperFunctions.dayLabel(date)}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: XSizes.defaultSpace),
        child: Column(
          children: [
            /// Search
            TextField(
              autofocus: !startWithScan,
              onChanged: controller.onSearchChanged,
              onSubmitted: controller.search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search food, e.g. roti, chawal, दही'.tr,
                prefixIcon: Icon(Iconsax.search_normal),
              ),
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Scan & Manual buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _scan(context),
                    icon: const Icon(Iconsax.scan_barcode),
                    label: Text('Scan'.tr),
                  ),
                ),
                const SizedBox(width: XSizes.spaceBtwItems),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openManual,
                    icon: const Icon(Iconsax.edit),
                    label: Text('Manual'.tr),
                  ),
                ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwItems),

            /// Results
            Expanded(
              child: Obx(() {
                final catalog = controller.catalogResults;
                final products = controller.productResults;
                if (controller.searching.value && catalog.isEmpty && products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!controller.searchedOnce.value && catalog.isEmpty && products.isEmpty) {
                  return _Hint(
                    icon: Iconsax.search_normal,
                    text: 'Search a food, scan a packaged product, or enter it manually.'.tr,
                  );
                }
                if (catalog.isEmpty && products.isEmpty) {
                  return _Hint(
                    icon: Iconsax.search_status,
                    text:
                        controller.productSearchError.value ??
                        'No match found. Use "Manual" to add it yourself.'.tr,
                  );
                }
                return ListView(
                  children: [
                    if (catalog.isNotEmpty) _ResultsLabel('Common foods'.tr),
                    ...catalog.map(
                      (food) => XFoodResultTile(food: food, onTap: () => _confirm(context, food)),
                    ),
                    if (products.isNotEmpty) _ResultsLabel('Packaged products'.tr),
                    ...products.map(
                      (food) => XFoodResultTile(food: food, onTap: () => _confirm(context, food)),
                    ),
                    if (controller.productSearchError.value != null)
                      Padding(
                        padding: const EdgeInsets.all(XSizes.md),
                        child: Text(
                          controller.productSearchError.value!,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    const SizedBox(height: XSizes.spaceBtwSections),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsLabel extends StatelessWidget {
  const _ResultsLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: XSizes.sm, bottom: XSizes.xs),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(XSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: XColors.darkGrey),
            const SizedBox(height: XSizes.spaceBtwItems),
            Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
