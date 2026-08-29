// Packages provider — loads wash packages from Firestore, cached for the session.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';

/// All packages sorted by `order`, each as a map with keys:
/// id, label, description, vehicleTypes, order
final packagesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.loadPackages();
});
