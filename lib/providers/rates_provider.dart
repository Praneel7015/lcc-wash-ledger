// Rates provider — loads rate map from Firestore, keeps it in memory.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../services/providers.dart';

final ratesProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final svc = ref.watch(firestoreServiceProvider);
  return svc.loadRates();
});

// Derived: amount for a given (type, package) selection
final selectedAmountProvider = Provider.autoDispose.family<int, ({String vehicleType, String packageId})>((ref, args) {
  final ratesAsync = ref.watch(ratesProvider);
  return ratesAsync.whenOrNull(
        data: (rates) => rates[rateKey(args.vehicleType, args.packageId)] ?? 0,
      ) ??
      0;
});
