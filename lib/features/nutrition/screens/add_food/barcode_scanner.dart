import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../common/widgets/appbar/appbar.dart';
import '../../../../utils/constants/sizes.dart';
import '../../models/scanned_barcode.dart';

/// -- Scans one barcode and returns it with Get.back(result: ScannedBarcode).
/// Scanning only looks the product up; nothing is added to the diary here.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _scanner = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );
  bool _handled = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcode = capture.barcodes.isEmpty ? null : capture.barcodes.first;
    final code = barcode?.rawValue;
    if (barcode == null || code == null || code.isEmpty) return;
    _handled = true;
    Get.back(result: ScannedBarcode(code, ScannedBarcode.formatName(barcode.format)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text('Scan product barcode'.tr)),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _scanner,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(XSizes.xl),
                  child: Text(
                    'The camera is not available. Allow camera access in your phone settings, or enter the food manually.'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(XSizes.defaultSpace),
            child: Text(
              'Point the camera at the barcode on the pack. You will confirm the quantity before anything is saved.'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}
