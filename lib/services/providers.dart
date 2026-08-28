// Firestore service provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_service.dart';
import 'storage_service.dart';
import 'ocr_service.dart';

export 'firestore_service.dart';
export 'storage_service.dart';
export 'ocr_service.dart';

final firestoreServiceProvider = Provider.autoDispose<FirestoreService>((ref) {
  return FirestoreService();
});

final storageServiceProvider = Provider.autoDispose<StorageService>((ref) {
  return StorageService();
});

final ocrServiceProvider = Provider.autoDispose<OcrService>((ref) {
  final svc = OcrService();
  ref.onDispose(svc.dispose);
  return svc;
});
