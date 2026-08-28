// ML Kit on-device OCR — extracts likely plate text from an image.

import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static final _plateRegex = RegExp(
    r'\b[A-Z]{2}[0-9]{1,2}[A-Z]{1,3}[0-9]{3,4}\b',
    caseSensitive: false,
  );

  Future<String> extractPlate(Uint8List imageBytes) async {
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size: const Size(1280, 720),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: 1280,
      ),
    );

    final result = await _recognizer.processImage(inputImage);

    for (final block in result.blocks) {
      final text = block.text.replaceAll(' ', '').toUpperCase();
      final match = _plateRegex.firstMatch(text);
      if (match != null) return match.group(0)!;
    }

    final allText = result.text.replaceAll('\n', ' ');
    final tokens = allText.split(' ')
      ..removeWhere((t) => t.isEmpty)
      ..sort((a, b) => b.length.compareTo(a.length));

    return tokens.isNotEmpty ? tokens.first.toUpperCase() : '';
  }

  void dispose() => _recognizer.close();
}
