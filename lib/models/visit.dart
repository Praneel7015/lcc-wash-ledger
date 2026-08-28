// Data model for a single car wash visit.

import 'package:cloud_firestore/cloud_firestore.dart';

class Visit {
  final String id;
  final String plate;
  final String? phone;
  final String vehicleType;
  final String packageId;
  final int amount;
  final bool paid;
  final String? workerId;
  final DateTime createdAt;
  final String? platePhotoUrl;
  final String? frontPhotoUrl;

  const Visit({
    required this.id,
    required this.plate,
    this.phone,
    required this.vehicleType,
    required this.packageId,
    required this.amount,
    required this.paid,
    this.workerId,
    required this.createdAt,
    this.platePhotoUrl,
    this.frontPhotoUrl,
  });

  factory Visit.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Visit(
      id: doc.id,
      plate: d['plate'] as String,
      phone: d['phone'] as String?,
      vehicleType: d['vehicleType'] as String,
      packageId: d['packageId'] as String,
      amount: (d['amount'] as num).toInt(),
      paid: d['paid'] as bool? ?? false,
      workerId: d['workerId'] as String?,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
      platePhotoUrl: d['platePhotoUrl'] as String?,
      frontPhotoUrl: d['frontPhotoUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'plate': plate,
        'phone': phone,
        'vehicleType': vehicleType,
        'packageId': packageId,
        'amount': amount,
        'paid': paid,
        'workerId': workerId,
        'createdAt': Timestamp.fromDate(createdAt),
        'platePhotoUrl': platePhotoUrl,
        'frontPhotoUrl': frontPhotoUrl,
      };

  Visit copyWith({
    String? phone,
    String? vehicleType,
    String? packageId,
    int? amount,
    bool? paid,
    String? platePhotoUrl,
    String? frontPhotoUrl,
  }) =>
      Visit(
        id: id,
        plate: plate,
        phone: phone ?? this.phone,
        vehicleType: vehicleType ?? this.vehicleType,
        packageId: packageId ?? this.packageId,
        amount: amount ?? this.amount,
        paid: paid ?? this.paid,
        workerId: workerId,
        createdAt: createdAt,
        platePhotoUrl: platePhotoUrl ?? this.platePhotoUrl,
        frontPhotoUrl: frontPhotoUrl ?? this.frontPhotoUrl,
      );
}
