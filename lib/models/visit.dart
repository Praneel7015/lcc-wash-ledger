// Data model for a single car wash visit.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

class Visit {
  final String id;
  final String plate;
  final String? phone;
  final String vehicleType;
  final String packageId;
  final int amount;
  final bool paid;
  final String? paymentMethod; // 'cash' | 'upi' | null
  final bool voided;
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
    this.paymentMethod,
    this.voided = false,
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
      paymentMethod: d['paymentMethod'] as String?,
      voided: d['voided'] as bool? ?? false,
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
        if (paymentMethod != null) 'paymentMethod': paymentMethod,
        'voided': voided,
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
    String? paymentMethod,
    bool clearPaymentMethod = false,
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
        paymentMethod:
            clearPaymentMethod ? null : (paymentMethod ?? this.paymentMethod),
        voided: voided,
        workerId: workerId,
        createdAt: createdAt,
        platePhotoUrl: platePhotoUrl ?? this.platePhotoUrl,
        frontPhotoUrl: frontPhotoUrl ?? this.frontPhotoUrl,
      );
}

class RevenueBreakdown {
  final int total;
  final int cash;
  final int upi;
  final int unknown;
  final int pending;

  const RevenueBreakdown({
    required this.total,
    required this.cash,
    required this.upi,
    required this.unknown,
    required this.pending,
  });

  int get collected => cash + upi + unknown;
}

RevenueBreakdown computeRevenueBreakdown(Iterable<Visit> visits) {
  var total = 0;
  var cash = 0;
  var upi = 0;
  var unknown = 0;
  var pending = 0;

  for (final v in visits) {
    total += v.amount;
    if (!v.paid) {
      pending += v.amount;
    } else if (v.paymentMethod == PaymentMethod.cash) {
      cash += v.amount;
    } else if (v.paymentMethod == PaymentMethod.upi) {
      upi += v.amount;
    } else {
      unknown += v.amount;
    }
  }

  return RevenueBreakdown(
    total: total,
    cash: cash,
    upi: upi,
    unknown: unknown,
    pending: pending,
  );
}
