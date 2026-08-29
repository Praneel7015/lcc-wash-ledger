// ML Kit on-device OCR — extracts likely plate text from an image.
// Uses fromFilePath via a temp file so ML Kit can handle JPEG/PNG natively.

import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static final _plateRegex = RegExp(
    r'\b[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{3,4}\b',
    caseSensitive: false,
  );

  Future<String> extractPlate(Uint8List imageBytes) async {
    // Write bytes to a temp file so ML Kit can decode the JPEG properly.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/plate_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final result = await _recognizer.processImage(inputImage);

      // First pass: look for full Indian plate pattern (e.g. KA01AB1234)
      for (final block in result.blocks) {
        final text = block.text.replaceAll(' ', '').toUpperCase();
        final match = _plateRegex.firstMatch(text);
        if (match != null) return match.group(0)!;
      }

      // Fallback: return the longest alphanumeric token found
      final allText = result.text.replaceAll('\n', ' ');
      final tokens = allText
          .split(' ')
          .map((t) => t.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), ''))
          .where((t) => t.length >= 4)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      return tokens.isNotEmpty ? tokens.first.toUpperCase() : '';
    } finally {
      // Clean up temp file
      if (await file.exists()) await file.delete();
    }
  }

  void dispose() => _recognizer.close();
}
