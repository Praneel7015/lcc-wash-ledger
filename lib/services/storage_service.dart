// Photo storage — compresses images and stores them as base64 in Firestore.
// Firebase Storage requires a paid plan; this keeps everything on the free tier.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  /// Compresses [bytes] and returns a data-URI string
  /// (data:image/jpeg;base64,<encoded>) suitable for storing in Firestore
  /// and rendering with [Image.memory] after base64 decoding.
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String folder,
    required String plate,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 600,
      quality: 60,
      format: CompressFormat.jpeg,
    );

    final encoded = base64Encode(compressed);
    return 'data:image/jpeg;base64,$encoded';
  }

  /// Decodes a data-URI back to raw bytes for [Image.memory].
  static Uint8List? decodeDataUri(String? dataUri) {
    if (dataUri == null || !dataUri.startsWith('data:image')) return null;
    final comma = dataUri.indexOf(',');
    if (comma == -1) return null;
    return base64Decode(dataUri.substring(comma + 1));
  }
}
