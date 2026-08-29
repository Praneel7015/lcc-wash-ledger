// Firestore service — visits, customers, rates, settings.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/constants.dart';
import '../models/customer.dart';
import '../models/visit.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── Visits ──────────────────────────────────────────────────────────

  Future<String> saveVisit(Visit visit) async {
    final ref = await _db.collection('visits').add(visit.toFirestore());
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
      await seedDefaultRates();
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
