// Customer record — identified by normalised plate number.

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String plate; // doc ID = normalised plate
  final String? phone;
  final int visitCount;
  final DateTime? lastVisitAt;

  const Customer({
    required this.plate,
    this.phone,
    required this.visitCount,
    this.lastVisitAt,
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Customer(
      plate: doc.id,
      phone: d['phone'] as String?,
      visitCount: (d['visitCount'] as num?)?.toInt() ?? 0,
      lastVisitAt: d['lastVisitAt'] != null
          ? (d['lastVisitAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'phone': phone,
        'visitCount': visitCount,
        'lastVisitAt':
            lastVisitAt != null ? Timestamp.fromDate(lastVisitAt!) : null,
      };
}
