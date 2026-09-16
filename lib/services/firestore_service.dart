// Firestore service — visits, customers, rates, settings.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/constants.dart';
import '../models/customer.dart';
import '../models/visit.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── Visits ──────────────────────────────────────────────────────────

  /// Writes a visit. An empty [Visit.id] gets a generated document id.
  ///
  /// When the caller supplies a stable id the write is create-if-absent inside
  /// a transaction, so re-sending the same wash — a retry, or a write whose
  /// response was lost in flight — resolves to the record that is already there
  /// instead of a second one. Deliberately not a plain `set`: that counts as an
  /// update, and firestore.rules only lets a worker change `paid` and
  /// `paymentMethod` on a visit that already exists, so a retry would be denied.
  /// Writes a visit using a server timestamp for `createdAt`. An empty
  /// [Visit.id] gets a generated document id.
  ///
  /// Uses the same create-if-absent transaction as [saveVisit] for idempotency.
  Future<String> saveVisitCreate(Visit visit) async {
    if (visit.id.isEmpty) {
      final ref = await _db.collection('visits').add(visit.toFirestoreCreate());
      return ref.id;
    }
    final ref = _db.collection('visits').doc(visit.id);
    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      tx.set(ref, visit.toFirestoreCreate());
    });
    return ref.id;
  }

  /// Updates the photo URLs on an existing visit document after upload.
  Future<void> updateVisitPhotos(
    String id,
    String platePhotoUrl,
    String frontPhotoUrl,
  ) {
    return _db.collection('visits').doc(id).update({
      'platePhotoUrl': platePhotoUrl,
      'frontPhotoUrl': frontPhotoUrl,
    });
  }

  Future<String> saveVisit(Visit visit) async {
    if (visit.id.isEmpty) {
      final ref = await _db.collection('visits').add(visit.toFirestore());
      return ref.id;
    }
    final ref = _db.collection('visits').doc(visit.id);
    await _db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      tx.set(ref, visit.toFirestore());
    });
    return ref.id;
  }

  Future<void> updateVisit(String id, Map<String, dynamic> fields) {
    return _db.collection('visits').doc(id).update(fields);
  }

  Future<void> voidVisit(String id) {
    return _db.collection('visits').doc(id).update({'voided': true});
  }

  Stream<List<Visit>> visitsForDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _db
        .collection('visits')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map(Visit.fromFirestore)
            .where((v) => !v.voided)
            .toList());
  }

  Future<List<Visit>> visitsForRange(DateTime from, DateTime to) async {
    final snap = await _db
        .collection('visits')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(from),
            isLessThan: Timestamp.fromDate(to.add(const Duration(days: 1))))
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map(Visit.fromFirestore)
        .where((v) => !v.voided)
        .toList();
  }

  Future<Visit?> getVisit(String id) async {
    final doc = await _db.collection('visits').doc(id).get();
    if (!doc.exists) return null;
    return Visit.fromFirestore(doc);
  }

  Future<bool> wasLoggedToday(String plate) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 1));
    final snap = await _db
        .collection('visits')
        .where('plate', isEqualTo: plate)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
            isLessThan: Timestamp.fromDate(end))
        .get();
    return snap.docs.map(Visit.fromFirestore).any((v) => !v.voided);
  }

  // ── Customers ───────────────────────────────────────────────────────

  Future<Customer?> getCustomer(String plate) async {
    final doc =
        await _db.collection('customers').doc(normalisePlate(plate)).get();
    if (!doc.exists) return null;
    return Customer.fromFirestore(doc);
  }

  Future<void> upsertCustomer(String plate, String? phone) async {
    final key = normalisePlate(plate);
    final ref = _db.collection('customers').doc(key);
    await ref.set({
      'phone': phone,
      'visitCount': FieldValue.increment(1),
      'lastVisitAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Rates ────────────────────────────────────────────────────────────

  Future<Map<String, int>> loadRates() async {
    final snap = await _db.collection('rates').get();
    if (snap.docs.isEmpty) {
      // Only the owner may write /rates. A worker hitting an empty rate table
      // used to crash here with permission-denied; fall back to the defaults
      // so the wash can still be logged.
      try {
        await seedDefaultRates();
      } on FirebaseException catch (e) {
        debugPrint('loadRates: could not seed defaults (${e.code}) — '
            'using in-memory defaults.');
      }
      return defaultRates;
    }
    return {
      for (final doc in snap.docs)
        doc.id: ((doc.data()['amountRupees'] as num?)?.toInt() ?? 0),
    };
  }

  Future<void> setRate(String vehicleType, String packageId, int amount) {
    final key = rateKey(vehicleType, packageId);
    return _db.collection('rates').doc(key).set({
      'vehicleType': vehicleType,
      'packageId': packageId,
      'amountRupees': amount,
    });
  }

  /// Backfills the `other` vehicle type onto all non-bike packages.
  ///
  /// When the `other` vehicle type was introduced in v1.2.1 the existing package
  /// documents in Firestore were NOT updated, so selecting "Other" on the type/
  /// package screen showed "No packages available" — the filtered list was empty.
  ///
  /// This migration is idempotent: it skips documents that already contain
  /// `'other'` and is a no-op once all packages are up to date.
  Future<void> migrateOtherVehicleType() async {
    final snap = await _db.collection('packages').get();
    final batch = _db.batch();
    var changed = false;
    for (final doc in snap.docs) {
      final data = doc.data();
      final types = List<String>.from(data['vehicleTypes'] ?? []);
      // Bike-only packages must NOT be made available for other vehicle types.
      if (types.contains(VehicleType.bike) && types.length == 1) continue;
      if (types.contains(VehicleType.other)) continue;
      batch.update(doc.reference, {
        'vehicleTypes': FieldValue.arrayUnion([VehicleType.other]),
      });
      changed = true;
    }
    if (changed) {
      await batch.commit();
      debugPrint('migrateOtherVehicleType: backfilled "other" onto packages.');
    }
  }

  Future<void> seedDefaultRates() async {
    final batch = _db.batch();
    defaultRates.forEach((key, amount) {
      final parts = key.split('__');
      batch.set(_db.collection('rates').doc(key), {
        'vehicleType': parts[0],
        'packageId': parts[1],
        'amountRupees': amount,
      });
    });
    await batch.commit();
  }

  // ── Settings ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSettings() async {
    final doc = await _db.collection('settings').doc('app').get();
    return doc.data() ?? {};
  }

  Future<void> updateSettings(Map<String, dynamic> fields) {
    return _db
        .collection('settings')
        .doc('app')
        .set(fields, SetOptions(merge: true));
  }

  // ── Packages ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> loadPackages() async {
    final snap = await _db
        .collection('packages')
        .orderBy('order')
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'label': data['label'] ?? doc.id,
        'description': data['description'] ?? '',
        'vehicleTypes': List<String>.from(data['vehicleTypes'] ?? []),
        'order': (data['order'] as num?)?.toInt() ?? 0,
      };
    }).toList();
  }

  Future<void> savePackage(
    String id,
    String label,
    String description,
    List<String> vehicleTypes,
    int order,
  ) {
    return _db.collection('packages').doc(id).set({
      'label': label,
      'description': description,
      'vehicleTypes': vehicleTypes,
      'order': order,
    });
  }

  Future<void> deletePackage(String id) async {
    final batch = _db.batch();
    batch.delete(_db.collection('packages').doc(id));
    // Delete all rate docs for this packageId
    final rateSnap = await _db
        .collection('rates')
        .where('packageId', isEqualTo: id)
        .get();
    for (final doc in rateSnap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ── Operators ────────────────────────────────────────────────────────

  /// Records the operator's display name so the owner dashboard can show
  /// a human-readable name instead of a raw Firebase UID.
  Future<void> upsertOperator(String uid, String name) {
    return _db.collection('users').doc(uid).set(
      {'name': name},
      SetOptions(merge: true),
    );
  }

  /// Resolves a set of worker UIDs to their display names.
  /// Returns a map of uid → name (missing entries fall back to the UID).
  Future<Map<String, String>> fetchOperatorNames(Set<String> uids) async {
    if (uids.isEmpty) return {};
    final futures = uids.map(
      (uid) => _db.collection('users').doc(uid).get(),
    );
    final docs = await Future.wait(futures);
    final result = <String, String>{};
    for (final doc in docs) {
      final name = (doc.data()?['name'] as String?)?.trim();
      result[doc.id] = (name != null && name.isNotEmpty) ? name : doc.id;
    }
    return result;
  }

  // ── Close-day trigger ────────────────────────────────────────────────

  Future<void> triggerCloseDayEmail() async {
    await _db.collection('emailTasks').add({
      'type': 'closeDay',
      'date': Timestamp.fromDate(DateTime.now()),
      'triggeredBy': FirebaseAuth.instance.currentUser?.uid,
      'status': 'pending',
    });
  }
}
