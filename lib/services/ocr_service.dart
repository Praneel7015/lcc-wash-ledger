// ML Kit on-device OCR — extracts likely plate text from an image.
// Handles multi-line Indian plates (cars + two-wheelers), confusion variants,
// and slot normalization.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

class OcrService {
  TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static final _standardPlate = RegExp(
    r'[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{1,4}',
    caseSensitive: false,
  );

  static final _bhPlate = RegExp(
    r'[0-9]{2}BH[0-9]{4}[A-Z]{1,2}',
    caseSensitive: false,
  );

  static final _vintagePlate = RegExp(
    r'[A-Z]{2}VA[A-Z]{1,2}[0-9]{4}',
    caseSensitive: false,
  );

  /// Noise tokens that appear on Indian plates / stickers and poison matching.
  static final _noise = RegExp(
    r'(INDIA|BHARAT|IND|GOVT|GOVERNMENT|TRANSPORT)',
    caseSensitive: false,
  );

  static const _swaps = {
    'O': '0',
    '0': 'O',
    'I': '1',
    '1': 'I',
    'L': '1',
    'S': '5',
    '5': 'S',
    'B': '8',
    '8': 'B',
    'Z': '2',
    '2': 'Z',
    'G': '6',
    '6': 'G',
  };

  Future<String> extractPlate(Uint8List imageBytes) async {
    try {
      return await _extractOnce(imageBytes);
    } catch (e) {
      // Native ML Kit can die after process death / bad model state.
      // Recreate the recognizer and retry once before giving up.
      debugPrint('OCR first attempt failed: $e — recreating recognizer');
      try {
        await _recognizer.close();
      } catch (_) {}
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      return await _extractOnce(imageBytes);
    }
  }

  Future<String> _extractOnce(Uint8List imageBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/plate_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes, flush: true);

    try {
      final inputImage = InputImage.fromFilePath(file.path);
      final result = await _recognizer.processImage(inputImage);

      debugPrint(
          'OCR raw text: "${result.text.replaceAll('\n', ' | ')}" '
          '(${result.blocks.length} blocks)');

      final candidates = <String>{};

      // Per-block and per-line, cleaned.
      for (final block in result.blocks) {
        candidates.add(_clean(block.text));
        for (final line in block.lines) {
          candidates.add(_clean(line.text));
        }
      }

      // Sort lines top→bottom so two-wheeler plates (KA01 / AB1234) join in
      // reading order even when ML Kit returns blocks out of sequence.
      final orderedLines = result.blocks
          .expand((b) => b.lines)
          .map((l) => (
                text: _clean(l.text),
                y: l.boundingBox.top,
              ))
          .where((l) => l.text.isNotEmpty)
          .toList()
        ..sort((a, b) => a.y.compareTo(b.y));

      final lines = orderedLines.map((l) => l.text).toList();

      // Consecutive pairs and triples (bike / multi-line plates).
      for (var i = 0; i < lines.length - 1; i++) {
        candidates.add(lines[i] + lines[i + 1]);
      }
      for (var i = 0; i < lines.length - 2; i++) {
        candidates.add(lines[i] + lines[i + 1] + lines[i + 2]);
      }

      // Full join of all lines in visual order — strongest signal for bikes.
      if (lines.length >= 2) {
        candidates.add(lines.join());
      }

      // Also try every unordered pair (covers weird block splits).
      for (var i = 0; i < lines.length; i++) {
        for (var j = 0; j < lines.length; j++) {
          if (i == j) continue;
          candidates.add(lines[i] + lines[j]);
        }
      }

      candidates.add(_clean(result.text));

      String? bestPlate;
      var bestScore = -1;

      for (final text in candidates) {
        if (text.isEmpty) continue;
        for (final variant in _confusionVariants(text)) {
          final scored = _bestMatch(variant);
          if (scored != null && scored.score > bestScore) {
            bestScore = scored.score;
            bestPlate = slotNormalizePlate(scored.plate);
          }
        }
      }

      if (bestPlate != null && bestPlate.isNotEmpty) {
        debugPrint('OCR best plate: $bestPlate (score=$bestScore)');
        return bestPlate;
      }

      // Fallback: longest alphanumeric token after digit-bias swaps.
      final tokens = result.text
          .replaceAll('\n', ' ')
          .split(' ')
          .map((t) =>
              t.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), ''))
          .map(_stripNoise)
          .where((t) => t.length >= 4)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));

      if (tokens.isEmpty) {
        debugPrint('OCR: no tokens found');
        return '';
      }

      final fallback = slotNormalizePlate(
        _applyDigitBias(tokens.first.toUpperCase()),
      );
      final out = fallback.isNotEmpty ? fallback : tokens.first.toUpperCase();
      debugPrint('OCR fallback plate: $out');
      return out;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  String _clean(String raw) => _stripNoise(
        raw.replaceAll(RegExp(r'[\s\-\n\r\.]'), '').toUpperCase(),
      );

  String _stripNoise(String text) => text.replaceAll(_noise, '');

  Set<String> _confusionVariants(String text) {
    if (text.isEmpty) return {text};
    final variants = <String>{
      text,
      _applyDigitBias(text),
      _applyLetterBias(text),
    };
    for (var i = 0; i < text.length; i++) {
      final alt = _swaps[text[i]];
      if (alt != null) {
        variants.add(text.substring(0, i) + alt + text.substring(i + 1));
      }
    }
    return variants;
  }

  String _applyDigitBias(String text) => text
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8')
      .replaceAll('Z', '2')
      .replaceAll('G', '6');

  String _applyLetterBias(String text) =>
      text.replaceAll('0', 'O').replaceAll('1', 'I');

  _ScoredPlate? _bestMatch(String text) {
    if (text.isEmpty) return null;
    _ScoredPlate? best;
    for (final entry in [
      (_bhPlate, 80),
      (_vintagePlate, 60),
      (_standardPlate, 100),
    ]) {
      final re = entry.$1;
      final base = entry.$2;
      for (final m in re.allMatches(text)) {
        final plate = m.group(0)!.toUpperCase();
        final lenBonus = plate.length;
        final completeBonus = _completenessBonus(plate);
        final score = base + lenBonus + completeBonus;
        if (best == null || score > best.score) {
          best = _ScoredPlate(plate, score);
        }
      }
    }
    return best;
  }

  int _completenessBonus(String plate) {
    if (_standardPlate.hasMatch(plate) && plate.length >= 10) return 50;
    if (_bhPlate.hasMatch(plate) && plate.length >= 9) return 30;
    if (_vintagePlate.hasMatch(plate) && plate.length >= 10) return 20;
    // Prefer fuller bike-style plates (8–9 chars) over short fragments.
    if (_standardPlate.hasMatch(plate) && plate.length >= 8) return 20;
    return 0;
  }

  void dispose() {
    _recognizer.close();
  }
}

class _ScoredPlate {
  final String plate;
  final int score;
  const _ScoredPlate(this.plate, this.score);
}
