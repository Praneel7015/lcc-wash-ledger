// Firestore service provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firestore_service.dart';
import 'ocr_service.dart';
import 'shake_service.dart';
import 'storage_service.dart';

export 'firestore_service.dart';
export 'ocr_service.dart';
export 'shake_service.dart';
export 'storage_service.dart';

// Non-autoDispose so the service instance survives across screen navigations
// and async _load() calls in ConsumerStatefulWidget.initState are not cancelled.
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final ocrServiceProvider = Provider<OcrService>((ref) {
  final svc = OcrService();
  ref.onDispose(svc.dispose);
  return svc;
});

final shakeServiceProvider = Provider<ShakeService>((ref) {
  return ShakeService();
});
