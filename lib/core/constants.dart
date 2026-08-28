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
  static const String exterior = 'exterior';
  static const String interior = 'interior';
  static const String full = 'full';
  static const String wax = 'wax';

  static const List<String> all = [exterior, interior, full, wax];

  static String label(String pkg) {
    switch (pkg) {
      case exterior:
        return 'Exterior';
      case interior:
        return 'Interior';
      case full:
        return 'Full Wash';
      case wax:
        return 'Wax & Polish';
      default:
        return pkg;
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
      '${VehicleType.hatchSedan}__${WashPackage.exterior}': 150,
      '${VehicleType.hatchSedan}__${WashPackage.interior}': 200,
      '${VehicleType.hatchSedan}__${WashPackage.full}': 300,
      '${VehicleType.hatchSedan}__${WashPackage.wax}': 500,
      '${VehicleType.suv}__${WashPackage.exterior}': 200,
      '${VehicleType.suv}__${WashPackage.interior}': 250,
      '${VehicleType.suv}__${WashPackage.full}': 400,
      '${VehicleType.suv}__${WashPackage.wax}': 700,
      '${VehicleType.bike}__${WashPackage.exterior}': 80,
      '${VehicleType.bike}__${WashPackage.interior}': 100,
      '${VehicleType.bike}__${WashPackage.full}': 150,
      '${VehicleType.bike}__${WashPackage.wax}': 250,
    };

String rateKey(String vehicleType, String packageId) =>
    '${vehicleType}__$packageId';

// Photo retention: 90 days in seconds
const int photoRetentionDays = 90;

// India plate normalisation: strip spaces, uppercase
String normalisePlate(String raw) =>
    raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
