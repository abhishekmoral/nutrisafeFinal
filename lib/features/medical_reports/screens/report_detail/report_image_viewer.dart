import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../common/widgets/appbar/appbar.dart';

/// -- Shows a photographed report inside the app (pinch to zoom). Nothing is saved to the phone.
class ReportImageViewer extends StatelessWidget {
  const ReportImageViewer({super.key, required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: XAppBar(showBackArrow: true, title: Text(title)),
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image.memory(
            bytes,
            semanticLabel: 'Photo of the report'.tr,
            errorBuilder: (_, _, _) => Text('This image cannot be shown.'.tr),
          ),
        ),
      ),
    );
  }
}
