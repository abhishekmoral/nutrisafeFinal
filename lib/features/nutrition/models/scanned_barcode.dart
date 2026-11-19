import 'package:mobile_scanner/mobile_scanner.dart';

/// A scanned retail barcode and its type (UPC-E codes are expanded on the server).
class ScannedBarcode {
  const ScannedBarcode(this.code, this.format);

  final String code;
  final String? format; // ean13 | ean8 | upca | upce

  static String? formatName(BarcodeFormat format) => switch (format) {
        BarcodeFormat.ean13 => 'ean13',
        BarcodeFormat.ean8 => 'ean8',
        BarcodeFormat.upcA => 'upca',
        BarcodeFormat.upcE => 'upce',
        _ => null,
      };
}
