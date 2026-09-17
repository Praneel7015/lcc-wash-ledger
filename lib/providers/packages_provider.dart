// Packages provider — loads wash packages from Firestore, cached for the session.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/providers.dart';

/// All packages sorted by `order`, each as a map with keys:
/// id, label, description, vehicleTypes, order
///
/// Runs the one-time `migrateOtherVehicleType` migration on first load after
/// the v1.4.0 update, then skips it permanently using a local flag so it never
/// charges an extra Firestore read+write on every session start.
final packagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = ref.watch(firestoreServiceProvider);

  // Only run migration if not already completed on this device.
  const migrationKey = 'migration_other_vehicle_type_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(migrationKey) != true) {
    await svc.migrateOtherVehicleType();
    await prefs.setBool(migrationKey, true);
  }

  return svc.loadPackages();
});
