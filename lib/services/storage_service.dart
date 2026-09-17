// Firebase Storage service — upload and compress photos.

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  // Pin the bucket explicitly. A mismatched default (legacy .appspot.com vs
  // .firebasestorage.app) makes putData fail with permission-denied / unknown
  // while Firestore continues to work — exactly the symptom we saw.
  final _storage = FirebaseStorage.instanceFor(
    bucket: 'wash-ledgar.firebasestorage.app',
  );
  final _uuid = const Uuid();

  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String folder,
    required String plate,
  }) async {
    // Compress best-effort. If the native compressor fails under R8 or on a
    // particular device, fall back to the original camera bytes so the wash
    // still gets a photo rather than failing the whole upload.
    var toUpload = bytes;
    try {
      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 720,
        quality: 70,
        format: CompressFormat.jpeg,
      );
      if (compressed.isNotEmpty) {
        toUpload = Uint8List.fromList(compressed);
      }
    } catch (e) {
      debugPrint('compress failed, uploading original bytes: $e');
    }

    final filename = '${_uuid.v4()}.jpg';
    // Sanitize plate for Storage path segments (spaces / slashes break paths).
    final safePlate = plate.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final ref = _storage.ref('$folder/$safePlate/$filename');

    await ref.putData(
      toUpload,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'plate': plate,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return await ref.getDownloadURL();
  }
}
