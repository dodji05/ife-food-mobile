// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle Order (commande)
// Correspond à la réponse de GET /orders et GET /orders/:id
// ─────────────────────────────────────────────────────────────────────────────

class OrderItem {
  final String productId;
  final String productName;
  final int    quantity;
  final double unitPrice;
  final String? note;
  /// Objet product complet retourné par l'API quand `include: { product: true }`.
  /// Contient `imageUrl`, `name` (Map multilingue), `category`, etc.
  /// Utile pour afficher la photo du produit dans la carte commande sans
  /// faire un appel séparé. `null` si l'API n'a pas inclus la relation.
  final Map<String, dynamic>? product;
  /// Total ligne (unitPrice × quantity) tel que persisté par le backend.
  /// On garde le calcul `subtotal` en getter pour cohérence client si jamais
  /// la valeur serveur diffère (ex: arrondi monétaire).
  final double totalPrice;

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.note,
    this.product,
    double? totalPrice,
  }) : totalPrice = totalPrice ?? (unitPrice * quantity);

  double get subtotal => unitPrice * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> j) {
    // Backend Prisma : pas de productName à plat. Si l'item inclut le product,
    // le nom est dans product.name (Json multilingue {fr, en}).
    final productMap = j['product'] as Map<String, dynamic>?;
    String resolvedName = j['productName'] as String? ?? '';
    if (resolvedName.isEmpty && productMap != null) {
      final raw = productMap['name'];
      if (raw is Map) {
        resolvedName = (raw['fr'] ?? raw['en'] ?? '').toString();
      } else if (raw is String) {
        resolvedName = raw;
      }
    }
    return OrderItem(
      productId:   j['productId']   as String? ?? '',
      productName: resolvedName,
      quantity:    j['quantity']    as int?    ?? 1,
      unitPrice:   (j['unitPrice']  as num?)?.toDouble() ?? 0.0,
      note:        j['note']        as String?,
      product:     productMap,
      totalPrice:  (j['totalPrice'] as num?)?.toDouble(),
    );
  }
}

class Order {
  final String id;
  final String clientId;
  final String professionalId;
  final String professionalName;
  final String status;   // PENDING_PAYMENT | PAID | PREPARING | READY | IN_DELIVERY | DELIVERED | CANCELLED
  final String paymentStatus; // PENDING | SUCCESS | FAILED | REFUNDED
  final List<OrderItem> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final String deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String? driverId;
  /// Relation driver jointe par le backend (driver.user.{name,phone,avatarUrl}).
  /// Null tant que pas assigné. Symétrique de ProOrder.driver.
  final Map<String, dynamic>? driver;
  final String? promoCode;
  final double discount;
  final double tipAmount;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  const Order({
    required this.id,
    required this.clientId,
    required this.professionalId,
    required this.professionalName,
    required this.status,
    required this.paymentStatus,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    this.driverId,
    this.driver,
    this.promoCode,
    this.discount   = 0.0,
    this.tipAmount  = 0.0,
    required this.createdAt,
    this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) {
    // Backend Prisma : `professional` est imbriqué (businessName/logoUrl).
    final pro = j['professional'] as Map<String, dynamic>?;
    final resolvedProName = (j['professionalName'] as String?)
                            ?? (pro?['businessName'] as String?)
                            ?? '';
    return Order(
      id:               j['id']               as String? ?? '',
      clientId:         j['clientId']         as String? ?? '',
      professionalId:   j['professionalId']   as String? ?? '',
      professionalName: resolvedProName,
      status:           j['status']           as String? ?? 'PENDING_PAYMENT',
      paymentStatus:    j['paymentStatus']    as String? ?? 'PENDING',
      items: (j['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((i) => OrderItem.fromJson(i))
          .toList(),
      subtotal:        (j['subtotal']        as num?)?.toDouble() ?? 0.0,
      deliveryFee:     (j['deliveryFee']     as num?)?.toDouble() ?? 0.0,
      // Backend Prisma → totalAmount. Fallback sur total.
      total:           ((j['totalAmount']    as num?) ?? (j['total'] as num?))?.toDouble() ?? 0.0,
      deliveryAddress:  j['deliveryAddress']  as String? ?? '',
      deliveryLat:     (j['deliveryLat']     as num?)?.toDouble(),
      deliveryLng:     (j['deliveryLng']     as num?)?.toDouble(),
      driverId:         j['driverId']         as String?,
      driver:           j['driver']           as Map<String, dynamic>?,
      promoCode:        j['promoCode']        as String?,
      // Backend Prisma → promoDiscount. Fallback sur discount.
      discount:        ((j['promoDiscount']  as num?) ?? (j['discount'] as num?))?.toDouble() ?? 0.0,
      tipAmount:       (j['tipAmount']       as num?)?.toDouble() ?? 0.0,
      createdAt:       DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      deliveredAt:     j['deliveredAt'] != null
          ? DateTime.tryParse(j['deliveredAt'] as String? ?? '')
          : null,
    );
  }

  // Helpers
  // Aliases
  double get totalAmount        => total;
  double get promoDiscount      => discount;
  int?   get estimatedDeliveryMin => null;
  Map<String, dynamic>? get professional => null;

  // ── Helpers driver (relation Prisma nested driver.user.*) ────────────────
  /// L'API renvoie driver.user.{name, firstName, phone, avatarUrl} car le
  /// modèle Driver wrappe un User. Les getters ci-dessous gèrent cette
  /// imbrication + un fallback sur driver.* plat au cas où l'API change.
  Map<String, dynamic>? get _driverUser =>
      driver?['user'] as Map<String, dynamic>?;

  /// Nom à afficher pour le livreur ou null si pas assigné.
  String? get driverName {
    final n = _driverUser?['name']
           ?? _driverUser?['firstName']
           ?? driver?['name']
           ?? driver?['firstName'];
    return n is String ? n : null;
  }

  /// Téléphone du livreur — utilisé par bouton 'Appeler' du tracking.
  String? get driverPhone =>
      (_driverUser?['phone'] ?? driver?['phone']) as String?;

  String? get driverAvatarUrl =>
      (_driverUser?['avatarUrl'] ?? driver?['avatarUrl']) as String?;

  String? get driverLicensePlate => driver?['licensePlate'] as String?;
  String? get driverVehicleType  => driver?['vehicleType']  as String?;

  /// True si un livreur est assigné à cette commande (driver != null).
  bool get hasDriver => driver != null;

  bool get isPaid       => paymentStatus == 'SUCCESS';
  bool get isActive     => ['PAID', 'PREPARING', 'READY', 'IN_DELIVERY'].contains(status);
  bool get isDelivered  => status == 'DELIVERED';
  bool get isCancelled  => status == 'CANCELLED';

  String get statusLabel => switch (status) {
    'PENDING_PAYMENT' => 'En attente de paiement',
    'PAID'            => 'Payée',
    'PREPARING'       => 'En préparation',
    'READY'           => 'Prête',
    'IN_DELIVERY'     => 'En livraison',
    'DELIVERED'       => 'Livrée',
    'CANCELLED'       => 'Annulée',
    _                 => status,
  };

  String get formattedTotal => '${total.toStringAsFixed(0)} F';
}
