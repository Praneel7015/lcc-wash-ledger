// Packages provider — loads wash packages from Firestore, cached for the session.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/providers.dart';

/// All packages sorted by `order`, each as a map with keys:
/// id, label, description, vehicleTypes, order
///
/// Runs the one-time `migrateOtherVehicleType` migration on first load after
/// the v1.4.0 update, then skips it permanently using a local flag so it never
/// charges an extra Firestore read+write on every session start.
///
/// Migration writes are **owner-only** in Firestore rules. Workers must never
/// be blocked if migrate throws permission-denied — always fall through to
/// `loadPackages()`. Transient failures (network) do NOT set the flag so an
/// owner can retry next launch.
final packagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = ref.watch(firestoreServiceProvider);

  const migrationKey = 'migration_other_vehicle_type_v1';
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(migrationKey) != true) {
    try {
      await svc.migrateOtherVehicleType();
      await prefs.setBool(migrationKey, true);
    } on FirebaseException catch (e) {
      debugPrint('migrateOtherVehicleType FirebaseException: ${e.code}');
      // Workers cannot write packages — stop retrying forever on this device.
      if (e.code == 'permission-denied') {
        await prefs.setBool(migrationKey, true);
      }
    } catch (e) {
      // Network / unknown — leave flag unset so a later owner session can retry.
      debugPrint('migrateOtherVehicleType failed (will retry later): $e');
    }
  }

  return svc.loadPackages();
});
