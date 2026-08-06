// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle Driver (livreur)
// Correspond à la réponse de GET /drivers/me et PATCH /drivers/me/toggle-availability
// ─────────────────────────────────────────────────────────────────────────────

class Driver {
  final String id;
  final String userId;
  final String vehicleType;   // BICYCLE | MOTORCYCLE | TRICYCLE | CAR | ON_FOOT
  final String status;        // PENDING | VALIDATED | SUSPENDED | ONLINE | OFFLINE
  final bool isAvailable;
  final String? licensePlate;
  final bool? isInsured;      // null = non concerné (à pied/vélo) ou pas déclaré
  final String? zoneCity;
  final String? zoneCountry;
  final double? zoneRadiusKm;
  final double? currentLat;
  final double? currentLng;
  final int maxConcurrentDeliveries;
  final List<Map<String, dynamic>> documents;

  const Driver({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.status,
    required this.isAvailable,
    this.licensePlate,
    this.isInsured,
    this.zoneCity,
    this.zoneCountry,
    this.zoneRadiusKm,
    this.currentLat,
    this.currentLng,
    this.maxConcurrentDeliveries = 3,
    this.documents = const [],
  });

  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
    id:                        j['id'] as String? ?? '',
    userId:                    j['userId'] as String? ?? '',
    vehicleType:               j['vehicleType'] as String? ?? 'MOTORCYCLE',
    status:                    j['status'] as String? ?? 'PENDING',
    isAvailable:               j['isAvailable'] as bool? ?? false,
    licensePlate:              j['licensePlate'] as String?,
    isInsured:                 j['isInsured'] as bool?,
    zoneCity:                  j['zoneCity'] as String?,
    zoneCountry:               j['zoneCountry'] as String?,
    zoneRadiusKm:              (j['zoneRadiusKm'] as num?)?.toDouble(),
    currentLat:                (j['currentLat'] as num?)?.toDouble(),
    currentLng:                (j['currentLng'] as num?)?.toDouble(),
    maxConcurrentDeliveries:   j['maxConcurrentDeliveries'] as int? ?? 3,
    documents: (j['documents'] as List? ?? [])
        .map((d) => d as Map<String, dynamic>)
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'vehicleType': vehicleType,
    'status': status,
    'isAvailable': isAvailable,
    'licensePlate': licensePlate,
    'isInsured': isInsured,
    'zoneCity': zoneCity,
    'zoneCountry': zoneCountry,
    'zoneRadiusKm': zoneRadiusKm,
    'currentLat': currentLat,
    'currentLng': currentLng,
    'maxConcurrentDeliveries': maxConcurrentDeliveries,
  };

  // Helpers métier
  bool get isOnline      => isAvailable && status == 'ONLINE';
  bool get isValidated   => status != 'PENDING' && status != 'SUSPENDED';
  bool get isPending     => status == 'PENDING';
  bool get isSuspended   => status == 'SUSPENDED';

  String get vehicleEmoji => switch (vehicleType) {
    'BICYCLE'    => '🚲',
    'MOTORCYCLE' => '🛵',
    'TRICYCLE'   => '🛺',
    'CAR'        => '🚗',
    'ON_FOOT'    => '🚶',
    _            => '🛵',
  };

  // Documents requis selon le type de véhicule + déclaration d'assurance.
  List<String> get requiredDocumentTypes {
    final types = switch (vehicleType) {
      'CAR' => ['DRIVER_LICENSE'],
      'MOTORCYCLE' || 'TRICYCLE' => ['ID_CARD'],
      _ => ['ID_CARD'], // BICYCLE, ON_FOOT
    };
    if ((vehicleType == 'MOTORCYCLE' || vehicleType == 'TRICYCLE' || vehicleType == 'CAR')
        && isInsured == true) {
      types.add('INSURANCE_PROOF');
    }
    return types;
  }

  Driver copyWith({
    String? vehicleType,
    String? status,
    bool? isAvailable,
    String? licensePlate,
    bool? isInsured,
    String? zoneCity,
    double? currentLat,
    double? currentLng,
  }) => Driver(
    id: id,
    userId: userId,
    vehicleType: vehicleType ?? this.vehicleType,
    status: status ?? this.status,
    isAvailable: isAvailable ?? this.isAvailable,
    licensePlate: licensePlate ?? this.licensePlate,
    isInsured: isInsured ?? this.isInsured,
    zoneCity: zoneCity ?? this.zoneCity,
    zoneCountry: zoneCountry,
    zoneRadiusKm: zoneRadiusKm,
    currentLat: currentLat ?? this.currentLat,
    currentLng: currentLng ?? this.currentLng,
    maxConcurrentDeliveries: maxConcurrentDeliveries,
    documents: documents,
  );
}
