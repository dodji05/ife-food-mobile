// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle Professional (restaurant / établissement)
// Correspond à la réponse de GET /professionals et GET /professionals/:id
//
// ⚠️ Modèle UNIFIÉ : merge des champs historiques (avgRating, deliveryTimeMin,
// deliveryFee, reviewCount) + des champs de configuration backend exposés par
// l'API pro standalone (phone, email, adminNote, commissionRate,
// deliveryRadiusKm, openingHours). Tous les nouveaux champs sont nullable
// pour préserver la rétro-compatibilité — l'API peut ne pas les retourner.
// ─────────────────────────────────────────────────────────────────────────────

class Professional {
  // ── Identité ──────────────────────────────────────────────────────────────
  final String  id;
  final String  userId;
  final String  businessName;
  final String? description;
  final String? logoUrl;
  final String? coverUrl;
  final String  category;       // RESTAURANT | BAKERY | GROCERY | PHARMACY | …
  final String  status;         // PENDING | VALIDATED | SUSPENDED | REJECTED

  // ── Contact (ex-getters renvoyant null → vrais champs) ────────────────────
  final String? phone;
  final String? email;

  // ── Localisation ──────────────────────────────────────────────────────────
  final double? lat;
  final double? lng;
  final String? address;
  final String? city;
  final String? country;

  // ── Télémétrie & UX (utilisés par les listes côté client) ─────────────────
  final double? avgRating;
  final int     reviewCount;
  final bool    isOpen;
  final int?    deliveryTimeMin;
  final double? deliveryFee;

  // ── Configuration métier (côté pro) ───────────────────────────────────────
  /// % de commission plateforme prélevé sur chaque commande (ex: 0.15).
  final double? commissionRate;

  /// Rayon de livraison max en km. Au-delà, le pro n'apparaît pas pour le client.
  final double? deliveryRadiusKm;

  /// Horaires d'ouverture par jour de la semaine.
  /// Format : `{'mon': {'open': '08:00', 'close': '22:00'}, 'tue': {...}, …}`
  /// `null` pour un jour fermé. Clés : mon, tue, wed, thu, fri, sat, sun.
  final Map<String, dynamic>? openingHours;

  /// Note administrateur (raison de refus, alerte interne, …). Visible pro.
  final String? adminNote;

  const Professional({
    required this.id,
    required this.userId,
    required this.businessName,
    this.description,
    this.logoUrl,
    this.coverUrl,
    required this.category,
    required this.status,
    this.phone,
    this.email,
    this.lat,
    this.lng,
    this.address,
    this.city,
    this.country,
    this.avgRating,
    this.reviewCount     = 0,
    this.isOpen          = true,
    this.deliveryTimeMin,
    this.deliveryFee,
    this.commissionRate,
    this.deliveryRadiusKm,
    this.openingHours,
    this.adminNote,
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
    phone:           j['phone']        as String?,
    email:           j['email']        as String?,
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
    deliveryFee:     (j['deliveryFee']     as num?)?.toDouble(),
    // Champs de configuration métier — exposés par l'API /professionals/me.
    commissionRate:   (j['commissionRate']   as num?)?.toDouble(),
    deliveryRadiusKm: (j['deliveryRadiusKm'] as num?)?.toDouble(),
    openingHours:     j['openingHours']      as Map<String, dynamic>?,
    adminNote:        j['adminNote']         as String?,
  );

  Map<String, dynamic> toJson() => {
    'id':               id,
    'userId':           userId,
    'businessName':     businessName,
    'description':      description,
    'logoUrl':          logoUrl,
    'coverUrl':         coverUrl,
    'category':         category,
    'status':           status,
    'phone':            phone,
    'email':            email,
    'lat':              lat,
    'lng':              lng,
    'address':          address,
    'city':             city,
    'country':          country,
    'avgRating':        avgRating,
    'reviewCount':      reviewCount,
    'isOpen':           isOpen,
    'deliveryTimeMin':  deliveryTimeMin,
    'deliveryFee':      deliveryFee,
    'commissionRate':   commissionRate,
    'deliveryRadiusKm': deliveryRadiusKm,
    'openingHours':     openingHours,
    'adminNote':        adminNote,
  };

  // ── Alias historiques utilisés par les écrans ────────────────────────────
  String? get coverImageUrl        => coverUrl;
  int?    get estimatedDeliveryMin => deliveryTimeMin;
  double? get distance             => null; // calculé côté API si besoin

  Professional copyWith({
    String? businessName,
    String? description,
    String? logoUrl,
    String? coverUrl,
    String? category,
    String? status,
    String? phone,
    String? email,
    double? lat,
    double? lng,
    String? address,
    String? city,
    String? country,
    double? avgRating,
    int?    reviewCount,
    bool?   isOpen,
    int?    deliveryTimeMin,
    double? deliveryFee,
    double? commissionRate,
    double? deliveryRadiusKm,
    Map<String, dynamic>? openingHours,
    String? adminNote,
  }) => Professional(
    id:               id,
    userId:           userId,
    businessName:     businessName     ?? this.businessName,
    description:      description      ?? this.description,
    logoUrl:          logoUrl          ?? this.logoUrl,
    coverUrl:         coverUrl         ?? this.coverUrl,
    category:         category         ?? this.category,
    status:           status           ?? this.status,
    phone:            phone            ?? this.phone,
    email:            email            ?? this.email,
    lat:              lat              ?? this.lat,
    lng:              lng              ?? this.lng,
    address:          address          ?? this.address,
    city:             city             ?? this.city,
    country:          country          ?? this.country,
    avgRating:        avgRating        ?? this.avgRating,
    reviewCount:      reviewCount      ?? this.reviewCount,
    isOpen:           isOpen           ?? this.isOpen,
    deliveryTimeMin:  deliveryTimeMin  ?? this.deliveryTimeMin,
    deliveryFee:      deliveryFee      ?? this.deliveryFee,
    commissionRate:   commissionRate   ?? this.commissionRate,
    deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
    openingHours:     openingHours     ?? this.openingHours,
    adminNote:        adminNote        ?? this.adminNote,
  );

  // ── Helpers statut ───────────────────────────────────────────────────────
  bool get isValidated => status == 'VALIDATED';
  bool get isPending   => status == 'PENDING';
  bool get isSuspended => status == 'SUSPENDED';
  bool get isRejected  => status == 'REJECTED';

  String get statusLabel => switch (status) {
    'PENDING'   => 'En attente de validation',
    'VALIDATED' => 'Validé ✓',
    'REJECTED'  => 'Refusé',
    'SUSPENDED' => 'Suspendu',
    _           => status,
  };

  // ── Helpers d'affichage ──────────────────────────────────────────────────
  String get ratingLabel => avgRating != null
      ? avgRating!.toStringAsFixed(1)
      : '—';

  String get deliveryTimeLabel => deliveryTimeMin != null
      ? '~$deliveryTimeMin min'
      : '—';

  String get categoryEmoji => switch (category) {
    'RESTAURANT'  => '🍽️',
    'BAKERY'      => '🥖',
    'GROCERY'     => '🛒',
    'SUPERMARKET' => '🏪',
    'PHARMACY'    => '💊',
    _             => '🏬',
  };

  // ── Helpers configuration métier ─────────────────────────────────────────
  /// `true` si la pro a configuré au moins un jour d'ouverture.
  bool get hasOpeningHours =>
      openingHours != null && openingHours!.isNotEmpty;

  /// Récupère les horaires d'un jour donné (`mon`, `tue`, …).
  /// Retourne `null` si le jour est fermé ou non configuré.
  Map<String, dynamic>? hoursFor(String dayKey) {
    final raw = openingHours?[dayKey];
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// % de commission affichable (ex: `15 %`). Fallback `—` si non défini.
  String get commissionLabel => commissionRate != null
      ? '${(commissionRate! * 100).toStringAsFixed(0)} %'
      : '—';

  /// Rayon de livraison affichable (ex: `5 km`). Fallback `—` si non défini.
  String get deliveryRadiusLabel => deliveryRadiusKm != null
      ? '${deliveryRadiusKm!.toStringAsFixed(deliveryRadiusKm! % 1 == 0 ? 0 : 1)} km'
      : '—';
}
