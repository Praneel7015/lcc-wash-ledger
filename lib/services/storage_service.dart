// Firebase Storage service — upload and compress photos.

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String folder,
    required String plate,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1280,
      minHeight: 720,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    final filename = '${_uuid.v4()}.jpg';
    final ref = _storage.ref('$folder/$plate/$filename');

    await ref.putData(
      Uint8List.fromList(compressed),
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
