// Packages provider — loads wash packages from Firestore, cached for the session.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

/// All packages sorted by `order`, each as a map with keys:
/// id, label, description, vehicleTypes, order
///
/// Also runs the one-time `migrateOtherVehicleType` migration each session so
/// that the 'other' vehicle type becomes visible to workers without requiring an
/// owner to open the Rates screen first.
final packagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = ref.watch(firestoreServiceProvider);
  // Idempotent: no-ops once every package already has 'other' in its list.
  await svc.migrateOtherVehicleType();
  return svc.loadPackages();
});
