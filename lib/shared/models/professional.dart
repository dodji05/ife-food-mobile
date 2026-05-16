// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle Professional (restaurant / établissement)
// Correspond à la réponse de GET /professionals et GET /professionals/:id
// ─────────────────────────────────────────────────────────────────────────────

class Professional {
  final String id;
  final String userId;
  final String businessName;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String category;       // RESTAURANT | BAKERY | GROCERY | ...
  final String status;         // PENDING | VALIDATED | SUSPENDED
  final double? lat;
  final double? lng;
  final String? address;
  final String? city;
  final String? country;
  final double? avgRating;
  final int    reviewCount;
  final bool   isOpen;
  final int?   deliveryTimeMin;
  final double? deliveryFee;

  const Professional({
    required this.id,
    required this.userId,
    required this.businessName,
    this.description,
    this.logoUrl,
    this.coverUrl,
    required this.category,
    required this.status,
    this.lat,
    this.lng,
    this.address,
    this.city,
    this.country,
    this.avgRating,
    this.reviewCount  = 0,
    this.isOpen       = true,
    this.deliveryTimeMin,
    this.deliveryFee,
  });

  factory Professional.fromJson(Map<String, dynamic> j) => Professional(
    id:              j['id']           as String? ?? '',
    userId:          j['userId']       as String? ?? '',
    businessName:    j['businessName'] as String? ?? '',
    description:     j['description']  as String?,
    logoUrl:         j['logoUrl']      as String?,
    // Backend Prisma → coverImageUrl. Fallback sur coverUrl si jamais ré-aplati.
    coverUrl:        (j['coverImageUrl'] as String?) ?? (j['coverUrl'] as String?),
    category:        j['category']     as String? ?? 'RESTAURANT',
    status:          j['status']       as String? ?? 'PENDING',
    lat:             (j['lat']         as num?)?.toDouble(),
    lng:             (j['lng']         as num?)?.toDouble(),
    address:         j['address']      as String?,
    city:            j['city']         as String?,
    country:         j['country']      as String?,
    avgRating:       (j['avgRating']   as num?)?.toDouble(),
    // reviewCount n'est pas exposé par getPublicProfile. Si _count est inclus,
    // on lit reviews._count, sinon on tombe sur reviewCount ou 0.
    reviewCount:     (j['reviewCount'] as int?)
                     ?? ((j['_count'] as Map<String, dynamic>?)?['reviews'] as int?)
                     ?? 0,
    isOpen:          j['isOpen']       as bool? ?? true,
    // deliveryTimeMin / deliveryFee ne sont pas dans le schéma Pro — ils
    // peuvent être calculés ailleurs (config plateforme ou Order) et passés
    // ad-hoc. Garder le parse défensif.
    deliveryTimeMin: (j['deliveryTimeMin'] as num?)?.toInt(),
    deliveryFee:     (j['deliveryFee'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id':              id,
    'userId':          userId,
    'businessName':    businessName,
    'description':     description,
    'logoUrl':         logoUrl,
    'coverUrl':        coverUrl,
    'category':        category,
    'status':          status,
    'lat':             lat,
    'lng':             lng,
    'address':         address,
    'city':            city,
    'country':         country,
    'avgRating':       avgRating,
    'reviewCount':     reviewCount,
    'isOpen':          isOpen,
    'deliveryTimeMin': deliveryTimeMin,
    'deliveryFee':     deliveryFee,
  };

  // Aliases utilisés par les écrans
  String? get coverImageUrl       => coverUrl;
  int?    get estimatedDeliveryMin => deliveryTimeMin;
  double? get distance            => null; // calculé côté API si besoin
  String? get phone               => null; // le téléphone est sur le modèle User
  Map<String, dynamic>? get openingHours => null; // retourné par l'API si besoin

  Professional copyWith({bool? isOpen}) => Professional(
    id: id, userId: userId, businessName: businessName,
    description: description, logoUrl: logoUrl, coverUrl: coverUrl,
    category: category, status: status, lat: lat, lng: lng,
    address: address, city: city, country: country,
    avgRating: avgRating, reviewCount: reviewCount,
    isOpen: isOpen ?? this.isOpen,
    deliveryTimeMin: deliveryTimeMin, deliveryFee: deliveryFee,
  );

  bool get isValidated => status == 'VALIDATED';
  bool get isPending   => status == 'PENDING';

  String get statusLabel => switch (status) {
    'PENDING'   => 'En attente de validation',
    'VALIDATED' => 'Validé ✓',
    'SUSPENDED' => 'Suspendu',
    _           => status,
  };

  String get ratingLabel => avgRating != null
      ? avgRating!.toStringAsFixed(1)
      : '—';
  String get deliveryTimeLabel => deliveryTimeMin != null
      ? '~$deliveryTimeMin min'
      : '—';
  String get categoryEmoji => switch (category) {
    'RESTAURANT' => '🍽️',
    'BAKERY'     => '🥖',
    'GROCERY'    => '🛒',
    'PHARMACY'   => '💊',
    _            => '🏪',
  };
}
