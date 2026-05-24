class DriverZone {
  final String id;
  final String name;
  final String city;
  final String country;
  final double radiusKm;
  final bool isDefault;
  final DateTime createdAt;

  const DriverZone({
    required this.id,
    required this.name,
    required this.city,
    required this.country,
    required this.radiusKm,
    required this.isDefault,
    required this.createdAt,
  });

  factory DriverZone.fromJson(Map<String, dynamic> j) => DriverZone(
    id:        j['id'] as String,
    name:      j['name'] as String,
    city:      j['city'] as String,
    country:   j['country'] as String? ?? 'BJ',
    radiusKm:  (j['radiusKm'] as num?)?.toDouble() ?? 10.0,
    isDefault: j['isDefault'] as bool? ?? false,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id':        id,
    'name':      name,
    'city':      city,
    'country':   country,
    'radiusKm':  radiusKm,
    'isDefault': isDefault,
  };

  DriverZone copyWith({
    String? name,
    String? city,
    String? country,
    double? radiusKm,
    bool?   isDefault,
  }) => DriverZone(
    id:        id,
    name:      name ?? this.name,
    city:      city ?? this.city,
    country:   country ?? this.country,
    radiusKm:  radiusKm ?? this.radiusKm,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt,
  );
}
