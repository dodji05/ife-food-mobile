// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle UserAddress
//
// Adresse de livraison sauvegardée du client. Une seule adresse par user peut
// être `isDefault=true` à la fois — garanti par le backend dans des transactions.
//
// Correspond aux endpoints :
//   GET    /user-addresses
//   POST   /user-addresses
//   PATCH  /user-addresses/:id
//   PATCH  /user-addresses/:id/default
//   DELETE /user-addresses/:id
// ─────────────────────────────────────────────────────────────────────────────

class UserAddress {
  final String  id;
  final String  userId;
  /// Étiquette courte ex: "Maison", "Bureau", "Chez Maman"
  final String  label;
  /// Ligne d'adresse complète, format libre
  final String  address;
  final String  city;
  /// Code ISO pays (BJ pour Bénin). Défaut backend = 'BJ'.
  final String  country;
  final double? lat;
  final double? lng;
  /// Instructions livreur ex: "Sonner 2 fois", "Code portail 1234"
  final String? instructions;
  final bool    isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserAddress({
    required this.id,
    required this.userId,
    required this.label,
    required this.address,
    required this.city,
    this.country = 'BJ',
    this.lat,
    this.lng,
    this.instructions,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserAddress.fromJson(Map<String, dynamic> j) => UserAddress(
    id:           j['id']           as String? ?? '',
    userId:       j['userId']       as String? ?? '',
    label:        j['label']        as String? ?? '',
    address:      j['address']      as String? ?? '',
    city:         j['city']         as String? ?? '',
    country:      j['country']      as String? ?? 'BJ',
    lat:          (j['lat']         as num?)?.toDouble(),
    lng:          (j['lng']         as num?)?.toDouble(),
    instructions: j['instructions'] as String?,
    isDefault:    j['isDefault']    as bool?   ?? false,
    createdAt:    (DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now()).toLocal(),
    updatedAt:    (DateTime.tryParse(j['updatedAt'] as String? ?? '')
                  ?? DateTime.tryParse(j['createdAt'] as String? ?? '')
                  ?? DateTime.now()).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id':           id,
    'userId':       userId,
    'label':        label,
    'address':      address,
    'city':         city,
    'country':      country,
    'lat':          lat,
    'lng':          lng,
    'instructions': instructions,
    'isDefault':    isDefault,
  };

  /// Payload partiel pour le POST/PATCH (sans id/userId/timestamps).
  Map<String, dynamic> toCreateOrUpdatePayload() => {
    'label':        label,
    'address':      address,
    'city':         city,
    'country':      country,
    if (lat != null) 'lat': lat,
    if (lng != null) 'lng': lng,
    if (instructions != null && instructions!.isNotEmpty)
      'instructions': instructions,
    'isDefault':    isDefault,
  };

  UserAddress copyWith({
    String? label,
    String? address,
    String? city,
    String? country,
    double? lat,
    double? lng,
    String? instructions,
    bool?   isDefault,
  }) => UserAddress(
    id:           id,
    userId:       userId,
    label:        label        ?? this.label,
    address:      address      ?? this.address,
    city:         city         ?? this.city,
    country:      country      ?? this.country,
    lat:          lat          ?? this.lat,
    lng:          lng          ?? this.lng,
    instructions: instructions ?? this.instructions,
    isDefault:    isDefault    ?? this.isDefault,
    createdAt:    createdAt,
    updatedAt:    updatedAt,
  );

  // ── Helpers d'affichage ──────────────────────────────────────────────────
  /// Texte court pour les listes : "Maison — Carré 1234, Cotonou"
  String get displaySummary => '$label — $address, $city';

  /// Icône emoji selon le label (best-effort sur les labels usuels FR).
  String get labelEmoji {
    final l = label.toLowerCase();
    if (l.contains('maison') || l.contains('home') || l.contains('chez')) return '🏠';
    if (l.contains('bureau') || l.contains('travail') || l.contains('work')) return '🏢';
    if (l.contains('école') || l.contains('school')) return '🏫';
    if (l.contains('hôtel') || l.contains('hotel')) return '🏨';
    return '📍';
  }

  /// `true` si on a des coordonnées GPS exploitables (pour Maps).
  bool get hasCoords => lat != null && lng != null;
}
