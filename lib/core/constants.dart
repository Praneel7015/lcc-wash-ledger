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

  // All packages available for cars (hatch/sedan + SUV)
  static const List<String> car = [exterior, full, underbody, detailing];

  // Bike gets its own single package
  static const List<String> bikeOnly = [bikeWash];

  // Full list used for rates seeding only
  static const List<String> all = [exterior, full, underbody, detailing, bikeWash];

  /// Returns the packages relevant for a given vehicle type.
  static List<String> forVehicle(String vehicleType) {
    if (vehicleType == VehicleType.bike) return bikeOnly;
    return car;
  }

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
