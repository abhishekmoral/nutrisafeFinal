import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../utils/helpers/label_text_parser.dart';

/// -- Reads the printed text of package-label photos on the phone (Google ML Kit, offline).
/// Only the text that is really on the photo is returned; nothing is sent to a server here.
class LabelOcrService {
  LabelOcrService._();

  /// One [OcrPage] per photo, in the order given.
  static Future<List<OcrPage>> readPhotos(List<String> paths) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final pages = <OcrPage>[];
      for (final path in paths) {
        final recognized = await recognizer.processImage(InputImage.fromFilePath(path));
        pages.add(OcrPage([
          for (final block in recognized.blocks)
            for (final line in block.lines)
              OcrLine(line.text, [
                for (final element in line.elements)
                  OcrWord(
                    element.text,
                    element.boundingBox.left,
                    element.boundingBox.top,
                    element.boundingBox.right,
                    element.boundingBox.bottom,
                  ),
              ]),
        ]));
      }
      return pages;
    } finally {
      await recognizer.close();
    }
  }
}
