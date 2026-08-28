// Rate entry: price in rupees for a (vehicleType × packageId) combination.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';

class Rate {
  final String vehicleType;
  final String packageId;
  final int amountRupees;

  const Rate({
    required this.vehicleType,
    required this.packageId,
    required this.amountRupees,
  });

  String get key => rateKey(vehicleType, packageId);

  factory Rate.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Rate(
      vehicleType: d['vehicleType'] as String,
      packageId: d['packageId'] as String,
      amountRupees: (d['amountRupees'] as num).toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'vehicleType': vehicleType,
        'packageId': packageId,
        'amountRupees': amountRupees,
      };
}
