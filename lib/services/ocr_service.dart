// ML Kit on-device OCR — extracts likely plate text from an image.
// Handles two-line Indian plates by joining lines before pattern matching.

import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  // Standard: KA01AB1234, KA1A1, etc.
  static final _standardPlate = RegExp(
    r'[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}',
    caseSensitive: false,
  );

  // Bharat series: 22BH3456AA
  static final _bhPlate = RegExp(
    r'[0-9]{2}BH[0-9]{4}[A-Z]{1,2}',
    caseSensitive: false,
  );

  // Vintage: KAVAAB1234
  static final _vintagePlate = RegExp(
    r'[A-Z]{2}VA[A-Z]{1,2}[0-9]{4}',
    caseSensitive: false,
  );

  Future<String> extractPlate(Uint8List imageBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/plate_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final result = await _recognizer.processImage(inputImage);

      final candidates = <String>[];

      // Per-block (single-line plates)
      for (final block in result.blocks) {
        candidates.add(_clean(block.text));
      }

      // Per-line
      for (final block in result.blocks) {
        for (final line in block.lines) {
          candidates.add(_clean(line.text));
        }
      }

      // Pairwise line joins (two-line plates: KA01 + AB1234)
      final lines = result.blocks
          .expand((b) => b.lines)
          .map((l) => _clean(l.text))
          .where((t) => t.isNotEmpty)
          .toList();
      for (var i = 0; i < lines.length - 1; i++) {
        candidates.add(lines[i] + lines[i + 1]);
      }

      // Full flattened text
      candidates.add(_clean(result.text));

      for (final text in candidates) {
        final match = _findPlate(text);
        if (match != null) return match;
      }

      // Fallback: longest alphanumeric token
      final tokens = result.text
          .replaceAll('\n', ' ')
          .split(' ')
          .map((t) => t.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), ''))
          .where((t) => t.length >= 4)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      return tokens.isNotEmpty ? tokens.first.toUpperCase() : '';
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  String _clean(String raw) =>
      raw.replaceAll(RegExp(r'[\s\-\n\r]'), '').toUpperCase();

  String? _findPlate(String text) {
    if (text.isEmpty) return null;
    for (final re in [_bhPlate, _vintagePlate, _standardPlate]) {
      final m = re.firstMatch(text);
      if (m != null) return m.group(0)!.toUpperCase();
    }
    return null;
  }

  void dispose() => _recognizer.close();
}
