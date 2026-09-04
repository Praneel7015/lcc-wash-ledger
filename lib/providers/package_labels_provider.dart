// Package id → display label, resolved from Firestore.
//
// Packages are editable in the owner dashboard and live in the `packages`
// collection, but several screens still called the deprecated
// `WashPackage.label()` fallback, which only knows the five original seed IDs.
// Any package the owner created showed up as a raw ID ("custom_pkg_1") on the
// dashboard tiles, the worker's today list, the save-wash summary and the visit
// detail screen.
//
// Use `ref.watch(packageLabelsProvider)` and `resolvePackageLabel(...)` instead
// of calling WashPackage.label() directly.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'packages_provider.dart';

/// Map of package id → label for every package defined in Firestore.
final packageLabelsProvider = FutureProvider<Map<String, String>>((ref) async {
  final packages = await ref.watch(packagesProvider.future);
  return {
    for (final p in packages) p['id'] as String: p['label'] as String,
  };
});

/// The label for [packageId], falling back to the built-in name for the
/// original seed packages and finally to the raw id.
String resolvePackageLabel(
  AsyncValue<Map<String, String>> labels,
  String packageId,
) {
  final resolved = labels.valueOrNull?[packageId];
  if (resolved != null && resolved.isNotEmpty) return resolved;
  return WashPackage.label(packageId);
}
