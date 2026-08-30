// App-wide constants: vehicle types, package names, rate keys.

class VehicleType {
  static const String hatchSedan = 'hatch_sedan';
  static const String suv = 'suv';
  static const String bike = 'bike';

  static const List<String> all = [hatchSedan, suv, bike];

  static String label(String type) {
    switch (type) {
      case hatchSedan:
        return 'Hatch / Sedan';
      case suv:
        return 'SUV';
      case bike:
        return 'Bike';
      default:
        return type;
    }
  }

  static String emoji(String type) {
    switch (type) {
      case hatchSedan:
        return '🚗';
      case suv:
        return '🚙';
      case bike:
        return '🏍';
      default:
        return '🚗';
    }
  }
}

class WashPackage {
  // IDs — stored in Firestore, do not rename
  static const String exterior = 'exterior';     // Express Exterior Wash
  static const String full = 'full';             // Exterior + Interior Wash
  static const String underbody = 'underbody';   // Exterior + Interior + Under Body
  static const String detailing = 'detailing';   // Full Detailing
  static const String bikeWash = 'bike_wash';    // Express Bike Wash (bike only)

  // Deprecated: packages are now stored in Firestore `packages` collection.
  // These are kept only as fallback constants for the seed script.
  @Deprecated('Load packages from Firestore via packagesProvider instead.')
  static const List<String> car = [exterior, full, underbody, detailing];

  @Deprecated('Load packages from Firestore via packagesProvider instead.')
  static const List<String> bikeOnly = [bikeWash];

  // Full list kept for rates seeding only — do not use in UI.
  static const List<String> all = [exterior, full, underbody, detailing, bikeWash];

  /// Deprecated: filter packages from Firestore by vehicleType client-side.
  @Deprecated('Load packages from Firestore via packagesProvider instead.')
  static List<String> forVehicle(String vehicleType) {
    if (vehicleType == VehicleType.bike) return bikeOnly;
    // ignore: deprecated_member_use_from_same_package
    return car;
  }

  /// Fallback label — prefer the `label` field from the Firestore package doc.
  static String label(String pkg) {
    switch (pkg) {
      case exterior:
        return 'Express Exterior Wash';
      case full:
        return 'Exterior + Interior Wash';
      case underbody:
        return 'Exterior + Interior + Under Body';
      case detailing:
        return 'Full Detailing';
      case bikeWash:
        return 'Express Bike Wash';
      default:
        return pkg;
    }
  }

  /// Fallback description — prefer the `description` field from Firestore.
  static String description(String pkg) {
    switch (pkg) {
      case exterior:
        return 'A fast rinse and shine when you\'re short on time.';
      case full:
        return 'Full clean, inside and out.';
      case underbody:
        return 'Full clean + vacuum, under body wash & tyre polish.';
      case detailing:
        return 'Deep clean, shampoo, wax, tyre shine — like new.';
      case bikeWash:
        return 'Quick exterior rinse and shine for two-wheelers.';
      default:
        return '';
    }
  }
}

class UserRole {
  static const String worker = 'worker';
  static const String owner = 'owner';
}

// Default rate matrix (rupees) — editable via owner dashboard.
// rateKey = '<vehicleType>__<packageId>'
Map<String, int> get defaultRates => {
      // Hatch / Sedan
      '${VehicleType.hatchSedan}__${WashPackage.exterior}': 199,
      '${VehicleType.hatchSedan}__${WashPackage.full}': 299,
      '${VehicleType.hatchSedan}__${WashPackage.underbody}': 399,
      '${VehicleType.hatchSedan}__${WashPackage.detailing}': 1299,
      // SUV
      '${VehicleType.suv}__${WashPackage.exterior}': 299,
      '${VehicleType.suv}__${WashPackage.full}': 349,
      '${VehicleType.suv}__${WashPackage.underbody}': 499,
      '${VehicleType.suv}__${WashPackage.detailing}': 1999,
      // Bike
      '${VehicleType.bike}__${WashPackage.bikeWash}': 64,
    };

String rateKey(String vehicleType, String packageId) =>
    '${vehicleType}__$packageId';

// Photo retention: 90 days
const int photoRetentionDays = 90;

// ── Payment method ───────────────────────────────────────────────────────────

class PaymentMethod {
  static const String cash = 'cash';
  static const String upi = 'upi';

  static String label(String? method) {
    switch (method) {
      case cash:
        return 'Cash';
      case upi:
        return 'UPI';
      default:
        return '';
    }
  }

  /// For reports/exports — legacy paid visits without a method show as Unknown.
  static String reportLabel({required bool paid, String? method}) {
    if (!paid) return '';
    switch (method) {
      case cash:
        return 'Cash';
      case upi:
        return 'UPI';
      default:
        return 'Unknown';
    }
  }
}

// ── India plate normalisation ─────────────────────────────────────────────────

const _digitFix = {
  'O': '0',
  'I': '1',
  'L': '1',
  'S': '5',
  'B': '8',
  'Z': '2',
  'G': '6',
};

const _letterFix = {'0': 'O', '1': 'I'};

String _fixDigits(String s) =>
    s.split('').map((c) => _digitFix[c] ?? c).join();

String _fixLetters(String s) =>
    s.split('').map((c) => _letterFix[c] ?? c).join();

/// Position-aware plate normalisation — fixes O/0, I/1 etc. by slot.
String slotNormalizePlate(String raw) {
  final p = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (p.isEmpty) return '';

  final bh = RegExp(r'^(\d{2})(BH)(\d{4})([A-Z]{1,2})$').firstMatch(p);
  if (bh != null) {
    return '${_fixDigits(bh.group(1)!)}BH${_fixDigits(bh.group(3)!)}${_fixLetters(bh.group(4)!)}';
  }

  final bhFlexible =
      RegExp(r'^([0-9OILSBZG]{2})(BH)([0-9OILSBZG]{4})([A-Z0-9]{1,2})$')
          .firstMatch(p);
  if (bhFlexible != null) {
    final normalized =
        '${_fixDigits(bhFlexible.group(1)!)}BH${_fixDigits(bhFlexible.group(3)!)}${_fixLetters(bhFlexible.group(4)!)}';
    if (RegExp(r'^\d{2}BH\d{4}[A-Z]{1,2}$').hasMatch(normalized)) {
      return normalized;
    }
  }

  final va = RegExp(r'^([A-Z]{2})(VA)([A-Z]{1,2})(\d{4})$').firstMatch(p);
  if (va != null) {
    return '${_fixLetters(va.group(1)!)}VA${_fixLetters(va.group(3)!)}${_fixDigits(va.group(4)!)}';
  }

  final vaFlexible =
      RegExp(r'^([A-Z0-9]{2})(VA)([A-Z0-9]{1,2})([0-9OILSBZG]{4})$')
          .firstMatch(p);
  if (vaFlexible != null) {
    final normalized =
        '${_fixLetters(vaFlexible.group(1)!)}VA${_fixLetters(vaFlexible.group(3)!)}${_fixDigits(vaFlexible.group(4)!)}';
    if (RegExp(r'^[A-Z]{2}VA[A-Z]{1,2}\d{4}$').hasMatch(normalized)) {
      return normalized;
    }
  }

  final standard = _parseStandardPlate(p);
  if (standard != null) return standard;

  return p;
}

String? _parseStandardPlate(String p) {
  if (p.length < 5) return null;
  final state = _fixLetters(p.substring(0, 2));
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(state)) return null;

  for (final distLen in [2, 1]) {
    if (p.length < 2 + distLen + 1) continue;
    final dist = _fixDigits(p.substring(2, 2 + distLen));
    if (!RegExp(r'^\d{1,2}$').hasMatch(dist)) continue;

    final afterDist = p.substring(2 + distLen);
    for (var seriesLen = 3; seriesLen >= 0; seriesLen--) {
      if (afterDist.length < seriesLen + 1) continue;
      final seriesRaw = afterDist.substring(0, seriesLen);
      final series = seriesLen == 0 ? '' : _fixLetters(seriesRaw);
      if (seriesLen > 0 && !RegExp(r'^[A-Z]+$').hasMatch(series)) continue;

      final num = _fixDigits(afterDist.substring(seriesLen));
      if (!RegExp(r'^\d{1,4}$').hasMatch(num)) continue;

      return '$state$dist$series$num';
    }
  }
  return null;
}

String normalisePlate(String raw) => slotNormalizePlate(raw);

/// Formats a normalised plate for display (e.g. KA01AB1234 → KA 01 AB 1234).
String formatIndianPlate(String raw) {
  final p = normalisePlate(raw);
  if (p.isEmpty) return '';

  // Bharat series: YY BH #### XX
  final bh = RegExp(r'^(\d{2})(BH)(\d{4})([A-Z]{1,2})$').firstMatch(p);
  if (bh != null) {
    return '${bh.group(1)} ${bh.group(2)} ${bh.group(3)} ${bh.group(4)}';
  }

  // Vintage: AA VA XX ####
  final va = RegExp(r'^([A-Z]{2})(VA)([A-Z]{1,2})(\d{4})$').firstMatch(p);
  if (va != null) {
    return '${va.group(1)} ${va.group(2)} ${va.group(3)} ${va.group(4)}';
  }

  // Standard: AA ## [A-Z]{0,3} ####
  final std =
      RegExp(r'^([A-Z]{2})(\d{1,2})([A-Z]{0,3})(\d{1,4})$').firstMatch(p);
  if (std != null) {
    final parts = [
      std.group(1)!,
      std.group(2)!,
      if (std.group(3)!.isNotEmpty) std.group(3)!,
      std.group(4)!,
    ];
    return parts.join(' ');
  }

  return p;
}
