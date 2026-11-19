import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../data/services/label_ocr_service.dart';
import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';
import '../../../../utils/helpers/label_text_parser.dart';
import '../../../../utils/localization/translations.dart';
import '../../../../utils/popups/loaders.dart';
import '../../models/product_draft.dart';

/// -- Last step of product discovery: photos of the pack, read on the phone (OCR).
/// Returns a [LabelReadResult] with Get.back (empty when the person chose to type the details).
class LabelCaptureScreen extends StatefulWidget {
  const LabelCaptureScreen({super.key, this.providers = const [], this.title});

  /// What each product database answered, shown so the person knows why photos are needed.
  final List<ProviderReport> providers;
  final String? title;

  @override
  State<LabelCaptureScreen> createState() => _LabelCaptureScreenState();
}

class _LabelCaptureScreenState extends State<LabelCaptureScreen> {
  static const _maxPhotos = 6;
  final _picker = ImagePicker();
  final _photos = <XFile>[];
  bool _reading = false;

  Future<void> _takePhoto() async {
    if (_photos.length >= _maxPhotos) return;
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera, maxWidth: 2400, imageQuality: 92);
      if (photo != null) setState(() => _photos.add(photo));
    } catch (_) {
      XLoaders.errorSnackBar(
        title: 'Camera not available'.tr,
        message: 'Allow camera access, or choose photos from the gallery.'.tr,
      );
    }
  }

  Future<void> _pickPhotos() async {
    final room = _maxPhotos - _photos.length;
    if (room <= 0) return;
    try {
      final picked = await _picker.pickMultiImage(maxWidth: 2400, imageQuality: 92, limit: room > 1 ? room : null);
      if (picked.isNotEmpty) setState(() => _photos.addAll(picked.take(room)));
    } catch (_) {
      XLoaders.errorSnackBar(title: 'Could not open the gallery'.tr, message: 'Please try again.'.tr);
    }
  }

  Future<void> _read() async {
    if (_photos.isEmpty || _reading) return;
    setState(() => _reading = true);
    try {
      final pages = await LabelOcrService.readPhotos(_photos.map((p) => p.path).toList());
      final result = XLabelTextParser.parse(pages);
      if (!mounted) return;
      if (result.isEmpty) {
        XLoaders.warningSnackBar(
          title: 'No label text found'.tr,
          message: 'Take a sharper photo in good light, holding the phone straight over the label.'.tr,
        );
        return;
      }
      Get.back(result: result);
    } catch (e) {
      XLoaders.errorSnackBar(title: 'Could not read the photos'.tr, message: 'Please try again.'.tr);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dark = XHelperFunctions.isDarkMode(context);
    final checked = widget.providers.where((p) => p.status != 'not_configured').toList();

    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text(widget.title ?? 'Read the package label'.tr)),
      body: ListView(
        padding: const EdgeInsets.all(XSizes.defaultSpace),
        children: [
          if (checked.isNotEmpty) ...[
            Text('This barcode is not in the product databases'.tr, style: textTheme.titleMedium),
            const SizedBox(height: XSizes.sm),
            Wrap(
              spacing: XSizes.sm,
              runSpacing: XSizes.sm,
              children: checked.map((p) => _ProviderChip(report: p)).toList(),
            ),
            const SizedBox(height: XSizes.spaceBtwSections),
          ],
          Text('Take clear photos of the pack'.tr, style: textTheme.titleMedium),
          const SizedBox(height: XSizes.sm),
          _Step(number: 1, text: 'The front, with the product name.'.tr),
          _Step(number: 2, text: 'The ingredients and the allergen statement ("Contains", "May contain").'.tr),
          _Step(number: 3, text: 'The nutrition table, including the "per 100 g" heading.'.tr),
          const SizedBox(height: XSizes.sm),
          Text(
            'The text is read on your phone. Only what is printed is used: nothing is guessed, and you check every value before saving.'
                .tr,
            style: textTheme.labelMedium,
          ),
          const SizedBox(height: XSizes.spaceBtwItems),

          /// Photos
          if (_photos.isNotEmpty)
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: XSizes.sm),
                itemBuilder: (_, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(XSizes.cardRadiusMd),
                      child: Image.file(File(_photos[i].path), width: 90, height: 110, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: InkWell(
                        onTap: _reading ? null : () => setState(() => _photos.removeAt(i)),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: dark ? XColors.black : XColors.white,
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_photos.isNotEmpty) const SizedBox(height: XSizes.spaceBtwItems),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reading || _photos.length >= _maxPhotos ? null : _takePhoto,
                  icon: const Icon(Iconsax.camera),
                  label: Text('Take photo'.tr),
                ),
              ),
              const SizedBox(width: XSizes.spaceBtwItems),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reading || _photos.length >= _maxPhotos ? null : _pickPhotos,
                  icon: const Icon(Iconsax.gallery),
                  label: Text('Gallery'.tr),
                ),
              ),
            ],
          ),
          const SizedBox(height: XSizes.spaceBtwItems),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _photos.isEmpty || _reading ? null : _read,
              icon: _reading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Iconsax.scan),
              label: Text(
                _photos.isEmpty
                    ? 'Read label'.tr
                    : 'Read {count} photo(s)'.trf({'count': _photos.length}),
              ),
            ),
          ),
          const SizedBox(height: XSizes.sm),
          Center(
            child: TextButton(
              onPressed: _reading ? null : () => Get.back(result: LabelReadResult()),
              child: Text('Enter the details myself'.tr),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: XSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: XColors.primary,
            child: Text('$number', style: const TextStyle(fontSize: 12, color: XColors.white)),
          ),
          const SizedBox(width: XSizes.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// "Open Food Facts: not found" / "USDA FoodData Central: unavailable".
class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.report});

  final ProviderReport report;

  static String statusLabel(String status) {
    switch (status) {
      case 'found':
      case 'cached':
        return 'found'.tr;
      case 'not_found':
        return 'not found'.tr;
      case 'rate_limited':
        return 'busy, try later'.tr;
      case 'not_allowed':
        return 'access not enabled'.tr;
      default:
        return 'unavailable'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ok = report.answered;
    return Chip(
      avatar: Icon(ok ? Iconsax.tick_circle : Iconsax.warning_2, size: 16, color: ok ? XColors.success : XColors.warning),
      label: Text('${report.label}: ${statusLabel(report.status)}'),
      visualDensity: VisualDensity.compact,
    );
  }
}
