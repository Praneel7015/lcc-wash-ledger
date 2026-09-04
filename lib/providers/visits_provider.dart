// Live visit streams, keyed by day.
//
// These exist so screens stop calling `FirestoreService.visitsForDay(...)`
// inside `build()`. Doing that tore down and recreated the Firestore snapshot
// listener on every single rebuild — including every keystroke in the
// dashboard search box — which re-read the whole day's documents each time and
// billed for it. Riverpod caches one stream per day key instead.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/visit.dart';
import '../services/providers.dart';

/// Truncates to midnight so the provider family key is stable across rebuilds.
/// `DateTime.now()` would produce a different key every frame and defeat the
/// cache entirely.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Live, non-voided visits for one day. Always pass a key from [startOfDay].
final visitsForDayProvider =
    StreamProvider.autoDispose.family<List<Visit>, DateTime>((ref, day) {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.visitsForDay(day);
});
