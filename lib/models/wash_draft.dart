// In-progress wash draft passed between worker screens.

class WashDraft {
  final String plate;
  final List<int> plateImageBytes;
  final List<int> frontImageBytes;
  final String vehicleType;
  final String packageId;
  final int amount;
  String? phone;
  bool paid;
  String? paymentMethod; // 'cash' | 'upi' | null

  WashDraft({
    required this.plate,
    required this.plateImageBytes,
    required this.frontImageBytes,
    required this.vehicleType,
    required this.packageId,
    required this.amount,
    this.phone,
    this.paid = true,
    this.paymentMethod,
  });

  WashDraft copyWith({
    String? phone,
    bool? paid,
    String? paymentMethod,
    bool clearPaymentMethod = false,
  }) =>
      WashDraft(
        plate: plate,
        plateImageBytes: plateImageBytes,
        frontImageBytes: frontImageBytes,
        vehicleType: vehicleType,
        packageId: packageId,
        amount: amount,
        phone: phone ?? this.phone,
        paid: paid ?? this.paid,
        paymentMethod: clearPaymentMethod
            ? null
            : (paymentMethod ?? this.paymentMethod),
      );
}
