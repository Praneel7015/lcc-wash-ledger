// ML Kit on-device OCR — extracts likely plate text from an image.
// Handles multi-line Indian plates (cars + two-wheelers), confusion variants,
// and slot normalization.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

class OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _rec =>
      _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

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

  /// Noise words glued onto OCR text (handled in [_stripNoiseTokens]).
  // (IND badge is stripped only as a prefix before a state code.)

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

  /// Prefer [imagePath] (original camera/gallery file). Rewriting bytes to a
  /// temp `.jpg` can corrupt HEIC/PNG payloads and make ML Kit return nothing.
  ///
  /// Returns '' on web — Google ML Kit is mobile-only.
  Future<String> extractPlate({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    if (kIsWeb) {
      debugPrint('OCR skipped: ML Kit is not available on web');
      return '';
    }
    assert(imagePath != null || imageBytes != null);
    try {
      return await _extractOnce(imagePath: imagePath, imageBytes: imageBytes);
    } catch (e) {
      debugPrint('OCR first attempt failed: $e — recreating recognizer');
      try {
        await _recognizer?.close();
      } catch (_) {}
      _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      return await _extractOnce(imagePath: imagePath, imageBytes: imageBytes);
    }
  }

  Future<String> _extractOnce({
    String? imagePath,
    Uint8List? imageBytes,
  }) async {
    File? tempFile;
    late final String path;

    if (imagePath != null && imagePath.isNotEmpty && await File(imagePath).exists()) {
      path = imagePath;
    } else {
      if (imageBytes == null || imageBytes.isEmpty) {
        throw StateError('OCR: no image path or bytes');
      }
      final dir = await getTemporaryDirectory();
      tempFile = File(
          '${dir.path}/plate_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(imageBytes, flush: true);
      path = tempFile.path;
    }

    try {
      final inputImage = InputImage.fromFilePath(path);
      final result = await _rec.processImage(inputImage);
      return _pickBestPlate(result);
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  String _pickBestPlate(RecognizedText result) {
    debugPrint(
        'OCR raw text: "${result.text.replaceAll('\n', ' | ')}" '
        '(${result.blocks.length} blocks)');

    final candidates = <String>{};

    for (final block in result.blocks) {
      candidates.add(_clean(block.text));
      for (final line in block.lines) {
        candidates.add(_clean(line.text));
      }
    }

    // Sort lines top→bottom for two-wheeler plates (KA01 / AB1234).
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

    for (var i = 0; i < lines.length - 1; i++) {
      candidates.add(lines[i] + lines[i + 1]);
    }
    for (var i = 0; i < lines.length - 2; i++) {
      candidates.add(lines[i] + lines[i + 1] + lines[i + 2]);
    }
    if (lines.length >= 2) {
      candidates.add(lines.join());
    }
    for (var i = 0; i < lines.length; i++) {
      for (var j = 0; j < lines.length; j++) {
        if (i == j) continue;
        candidates.add(lines[i] + lines[j]);
      }
    }

    candidates.add(_clean(result.text));

    // Also strip a leading/trailing standalone "IND" (blue India badge).
    final strippedInd = <String>{};
    for (final c in candidates) {
      strippedInd.add(c.replaceFirst(RegExp(r'^IND'), ''));
      strippedInd.add(c.replaceFirst(RegExp(r'IND$'), ''));
    }
    candidates.addAll(strippedInd);

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

    final tokens = result.text
        .replaceAll('\n', ' ')
        .split(' ')
        .map((t) =>
            t.replaceAll(RegExp(r'[^A-Z0-9]', caseSensitive: false), ''))
        .map(_stripNoiseTokens)
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
  }

  String _clean(String raw) {
    final upper = raw.replaceAll(RegExp(r'[\s\-\n\r\.]'), '').toUpperCase();
    return _stripNoiseTokens(upper);
  }

  String _stripNoiseTokens(String text) {
    var t = text.toUpperCase();
    // Remove whole noise words that may have been glued on after space strip.
    t = t.replaceAll('INDIA', '');
    t = t.replaceAll('BHARAT', '');
    t = t.replaceAll('GOVERNMENT', '');
    t = t.replaceAll('GOVT', '');
    t = t.replaceAll('TRANSPORT', '');
    // Standalone IND badge only when it is a prefix/suffix, not mid-plate.
    if (t.startsWith('IND') && t.length > 3) {
      final rest = t.substring(3);
      if (RegExp(r'^[A-Z]{2}').hasMatch(rest)) t = rest;
    }
    return t;
  }

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
        final score = base + plate.length + _completenessBonus(plate);
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
    if (_standardPlate.hasMatch(plate) && plate.length >= 8) return 20;
    return 0;
  }

  void dispose() {
    _recognizer?.close();
    _recognizer = null;
  }
}

class _ScoredPlate {
  final String plate;
  final int score;
  const _ScoredPlate(this.plate, this.score);
}
