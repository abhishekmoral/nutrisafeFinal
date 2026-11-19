import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../common/widgets/custom_shapes/containers/rounded_container.dart';
import '../../../../common/widgets/texts/section_heading.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/helpers/label_text_parser.dart';
import '../../../../utils/localization/translations.dart';
import '../../controllers/product_review_controller.dart';
import '../../models/food_item_model.dart';
import '../../models/product_draft.dart';
import 'label_capture.dart';

/// -- Check a packaged product before it is saved. Every value shows where it came from;
/// values the databases disagree on are flagged until the person picks one.
/// Returns the saved product as a [FoodItemModel] with Get.back.
class ProductReviewScreen extends StatelessWidget {
  const ProductReviewScreen({super.key, required this.draft});

  final ProductDraft draft;

  static const _nutrientLabels = {
    'calories': ('Energy', 'kcal'),
    'protein_g': ('Protein', 'g'),
    'carbs_g': ('Carbohydrates', 'g'),
    'sugar_g': ('Total sugars', 'g'),
    'fat_g': ('Total fat', 'g'),
    'saturated_fat_g': ('Saturated fat', 'g'),
    'fiber_g': ('Fibre', 'g'),
    'sodium_mg': ('Sodium', 'mg'),
  };

  Future<void> _readLabel(ProductReviewController controller) async {
    final result = await Get.to<LabelReadResult>(
      () => LabelCaptureScreen(title: 'Read missing values from the pack'.tr),
      preventDuplicates: false,
    );
    if (result != null && !result.isEmpty) controller.applyLabel(result);
  }

  Future<void> _save(BuildContext context, ProductReviewController controller) async {
    final open = controller.openConflicts;
    if (open.isNotEmpty) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Some values differ'.tr),
          content: Text(
            'The product databases disagree on {count} value(s), marked in orange. Check them against the pack before saving.'
                .trf({'count': open.length}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Check again'.tr)),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save anyway'.tr)),
          ],
        ),
      );
      if (go != true) return;
    }
    final food = await controller.save();
    if (food != null) Get.back<FoodItemModel>(result: food);
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProductReviewController(draft), tag: draft.barcode ?? 'new');
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Check product details'.tr)),
      body: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(XSizes.defaultSpace),
          children: [
            /// Where the details come from
            Obx(() => _SummaryCard(draft: controller.draft.value, openConflicts: controller.openConflicts.length)),
            const SizedBox(height: XSizes.spaceBtwSections),

            /// Product
            XSectionHeading(title: 'Product'.tr, showActionButton: false),
            const SizedBox(height: XSizes.spaceBtwItems),
            _TextInput(controller: controller, keyName: 'name', label: 'Product name'.tr, required: true),
            _TextInput(controller: controller, keyName: 'brand', label: 'Brand'.tr),
            _TextInput(controller: controller, keyName: 'net_quantity', label: 'Net quantity (e.g. 250 g)'.tr),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _NumberInput(controller: controller, keyName: 'serving_size', label: 'Serving size'.tr),
                ),
                const SizedBox(width: XSizes.spaceBtwItems),
                Expanded(
                  flex: 2,
                  child: Obx(
                    () => DropdownButtonFormField<String>(
                      key: ValueKey('unit-${controller.servingUnit.value}'),
                      initialValue: controller.servingUnit.value,
                      decoration: InputDecoration(labelText: 'Unit'.tr),
                      items: const ['g', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => controller.servingUnit.value = v ?? 'g',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: XSizes.spaceBtwSections),

            /// Ingredients & allergens
            XSectionHeading(title: 'Ingredients and allergens'.tr, showActionButton: false),
            const SizedBox(height: XSizes.spaceBtwItems),
            _TextInput(controller: controller, keyName: 'ingredients_text', label: 'Ingredients'.tr, maxLines: 5),
            _AllergenPicker(controller: controller, keyName: 'allergens', title: 'Contains'.tr, list: controller.allergens),
            const SizedBox(height: XSizes.spaceBtwItems),
            _AllergenPicker(
              controller: controller,
              keyName: 'may_contain',
              title: 'May contain (traces)'.tr,
              list: controller.mayContain,
            ),
            const SizedBox(height: XSizes.spaceBtwSections),

            /// Nutrition
            XSectionHeading(title: 'Nutrition'.tr, showActionButton: false),
            const SizedBox(height: XSizes.spaceBtwItems),
            Obx(
              () => DropdownButtonFormField<String>(
                key: ValueKey('basis-${controller.basis.value}'),
                initialValue: controller.basis.value,
                decoration: InputDecoration(labelText: 'Values are'.tr),
                items: [
                  DropdownMenuItem(value: 'per_100g', child: Text('per 100 g'.tr)),
                  DropdownMenuItem(value: 'per_100ml', child: Text('per 100 ml'.tr)),
                  DropdownMenuItem(value: 'per_serving', child: Text('per serving'.tr)),
                ],
                onChanged: (v) {
                  controller.basis.value = v ?? 'per_100g';
                  controller.formKey.currentState?.validate();
                },
              ),
            ),
            Obx(() => _FieldNote(controller: controller, keyName: 'basis', field: controller.draft.value.fields['basis'])),
            const SizedBox(height: XSizes.spaceBtwItems),
            ..._nutrientLabels.entries.map(
              (e) => _NumberInput(
                controller: controller,
                keyName: e.key,
                label: '${e.value.$1.tr} (${e.value.$2})',
              ),
            ),
            Text(
              'Leave a value empty if it is not printed on the pack. Empty means unknown, never zero.'.tr,
              style: textTheme.labelMedium,
            ),
            const SizedBox(height: XSizes.spaceBtwSections),

            /// Actions
            Obx(
              () => controller.hasEmptyFields || controller.draft.value.isNotFound
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: XSizes.spaceBtwItems),
                      child: OutlinedButton.icon(
                        onPressed: controller.saving.value ? null : () => _readLabel(controller),
                        icon: const Icon(Iconsax.camera),
                        label: Text('Fill empty fields from pack photos'.tr),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Obx(
              () => ElevatedButton(
                onPressed: controller.saving.value ? null : () => _save(context, controller),
                child: controller.saving.value
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Save product'.tr),
              ),
            ),
            const SizedBox(height: XSizes.sm),
            Text(
              'Saved products are kept in your account, so the next scan of this barcode is instant.'.tr,
              textAlign: TextAlign.center,
              style: textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// -- Top card: which databases knew the product, conflicts, unavailable databases.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.draft, required this.openConflicts});

  final ProductDraft draft;
  final int openConflicts;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dark = XHelperFunctions.isDarkMode(context);
    final fromLabel = draft.fields.values.any((f) => f.source == ProductDraft.labelSource);
    final image = draft.text('image_url');
    final unavailable = draft.unavailable;

    return XRoundedContainer(
      backgroundColor: dark ? XColors.darkerGrey : XColors.lightContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (image != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(XSizes.cardRadiusSm),
                  child: Image.network(
                    image,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56, child: Icon(Iconsax.box)),
                  ),
                ),
                const SizedBox(width: XSizes.spaceBtwItems),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.isNotFound && !fromLabel
                          ? 'Not found in the product databases'.tr
                          : (draft.sourceSummary.isEmpty
                                ? 'Enter the details from the pack'.tr
                                : 'From: {sources}'.trf({'sources': draft.sourceSummary})),
                      style: textTheme.titleSmall,
                    ),
                    if (draft.barcode != null)
                      Text('Barcode {code}'.trf({'code': draft.barcode}), style: textTheme.labelMedium),
                    if (draft.indianBarcode)
                      Text('Registered in India (GS1 India)'.tr, style: textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: XSizes.sm),
          Text(
            fromLabel
                ? 'Text recognition can misread numbers. Compare each value with the pack.'.tr
                : 'Product databases can be out of date. Compare each value with the pack before saving.'.tr,
            style: textTheme.bodySmall,
          ),
          if (openConflicts > 0) ...[
            const SizedBox(height: XSizes.sm),
            Row(
              children: [
                const Icon(Iconsax.warning_2, size: 18, color: XColors.warning),
                const SizedBox(width: XSizes.xs),
                Expanded(
                  child: Text(
                    '{count} value(s) differ between databases. Pick the one on your pack.'.trf({'count': openConflicts}),
                    style: textTheme.bodySmall!.copyWith(color: XColors.warning),
                  ),
                ),
              ],
            ),
          ],
          if (unavailable.isNotEmpty) ...[
            const SizedBox(height: XSizes.sm),
            Text(
              'Not checked right now: {names}'.trf({'names': unavailable.map((p) => p.label).join(', ')}),
              style: textTheme.labelMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.keyName,
    required this.label,
    this.required = false,
    this.maxLines = 1,
  });

  final ProductReviewController controller;
  final String keyName;
  final String label;
  final bool required;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSizes.spaceBtwInputFields),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller.inputs[keyName],
            minLines: 1,
            maxLines: maxLines,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: required ? '$label *' : label),
            validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required'.tr : null : null,
            onChanged: (_) => controller.markEdited(keyName),
          ),
          Obx(() => _FieldNote(controller: controller, keyName: keyName, field: controller.draft.value.fields[keyName])),
        ],
      ),
    );
  }
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({required this.controller, required this.keyName, required this.label});

  final ProductReviewController controller;
  final String keyName;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSizes.spaceBtwInputFields),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller.inputs[keyName],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: label),
            validator: (v) => controller.validateNumber(keyName, v),
            onChanged: (_) => controller.markEdited(keyName),
          ),
          Obx(() => _FieldNote(controller: controller, keyName: keyName, field: controller.draft.value.fields[keyName])),
        ],
      ),
    );
  }
}

class _AllergenPicker extends StatelessWidget {
  const _AllergenPicker({required this.controller, required this.keyName, required this.title, required this.list});

  final ProductReviewController controller;
  final String keyName;
  final String title;
  final RxList<String> list;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: XSizes.xs),
          Wrap(
            spacing: XSizes.sm,
            runSpacing: XSizes.xs,
            children: controller.allergenOptions
                .map(
                  (a) => FilterChip(
                    label: Text(a.tr),
                    selected: list.contains(a),
                    onSelected: (_) => controller.toggle(list, a, keyName),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
          _FieldNote(controller: controller, keyName: keyName, field: controller.draft.value.fields[keyName]),
        ],
      ),
    );
  }
}

/// -- Small line under a field: source and confidence, or the values that disagree.
class _FieldNote extends StatelessWidget {
  const _FieldNote({required this.controller, required this.keyName, required this.field});

  final ProductReviewController controller;
  final String keyName;
  final ProductField? field;

  static String _confidence(String c) => switch (c) {
        'high' => 'high confidence'.tr,
        'low' => 'please check'.tr,
        _ => 'check against the pack'.tr,
      };

  static String _show(Object? value) {
    if (value is num) return XHelperFunctions.formatNumber(value, decimals: 2);
    if (value is List) return value.isEmpty ? '–' : value.map((e) => e.toString().tr).join(', ');
    final text = value?.toString() ?? '–';
    return text.length > 60 ? '${text.substring(0, 60)}…' : text;
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    final f = field;
    if (f == null) {
      return Padding(
        padding: const EdgeInsets.only(top: XSizes.xs),
        child: Text('Not found: enter it from the pack if printed'.tr, style: style),
      );
    }

    final conflictOpen = f.isConflict && !controller.resolved.contains(keyName);
    final note = StringBuffer('${f.sourceLabel} · ${_confidence(f.confidence)}');
    if (f.status == 'converted' && f.original != null) {
      note.write(' · ${'converted from {original}'.trf({'original': f.original})}');
    }
    if (f.source == ProductDraft.labelSource && f.original != null && f.original!.length < 80) {
      note.write(' · ${'read as "{text}"'.trf({'text': f.original})}');
    }

    return Padding(
      padding: const EdgeInsets.only(top: XSizes.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.toString(), style: style),
          if (conflictOpen) ...[
            const SizedBox(height: XSizes.xs),
            Text(
              'Sources differ. Pick the value printed on your pack:'.tr,
              style: style!.copyWith(color: XColors.warning, fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: XSizes.sm,
              children: [
                ActionChip(
                  label: Text('${f.sourceLabel}: ${_show(f.value)}'),
                  onPressed: () => controller.keepValue(keyName),
                  visualDensity: VisualDensity.compact,
                ),
                ...f.alternatives.map(
                  (a) => ActionChip(
                    label: Text('${a.sourceLabel}: ${_show(a.value)}'),
                    onPressed: () => controller.chooseAlternative(keyName, a.value),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
