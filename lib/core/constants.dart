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

// India plate normalisation: strip spaces, uppercase
String normalisePlate(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

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
