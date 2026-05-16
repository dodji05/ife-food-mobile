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

  const OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.note,
  });

  double get subtotal  => unitPrice * quantity;
  double get totalPrice => subtotal;
  Map<String, dynamic>? get product => null; // enrichi par l'API si besoin

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    productId:   j['productId']   as String? ?? '',
    productName: j['productName'] as String? ?? '',
    quantity:    j['quantity']    as int? ?? 1,
    unitPrice:   (j['unitPrice']  as num?)?.toDouble() ?? 0.0,
    note:        j['note']        as String?,
  );
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
  final String? promoCode;
  final double discount;
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
    this.promoCode,
    this.discount     = 0.0,
    required this.createdAt,
    this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
    id:               j['id']               as String? ?? '',
    clientId:         j['clientId']         as String? ?? '',
    professionalId:   j['professionalId']   as String? ?? '',
    professionalName: j['professionalName'] as String? ?? '',
    status:           j['status']           as String? ?? 'PENDING_PAYMENT',
    paymentStatus:    j['paymentStatus']    as String? ?? 'PENDING',
    items: (j['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((i) => OrderItem.fromJson(i))
        .toList(),
    subtotal:        (j['subtotal']        as num?)?.toDouble() ?? 0.0,
    deliveryFee:     (j['deliveryFee']     as num?)?.toDouble() ?? 0.0,
    total:           (j['total']           as num?)?.toDouble() ?? 0.0,
    deliveryAddress:  j['deliveryAddress']  as String? ?? '',
    deliveryLat:     (j['deliveryLat']     as num?)?.toDouble(),
    deliveryLng:     (j['deliveryLng']     as num?)?.toDouble(),
    driverId:         j['driverId']         as String?,
    promoCode:        j['promoCode']        as String?,
    discount:        (j['discount']        as num?)?.toDouble() ?? 0.0,
    createdAt:       DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    deliveredAt:     j['deliveredAt'] != null
        ? DateTime.tryParse(j['deliveredAt'] as String? ?? '')
        : null,
  );

  // Helpers
  // Aliases
  double get totalAmount        => total;
  double get promoDiscount      => discount;
  int?   get estimatedDeliveryMin => null;
  Map<String, dynamic>? get professional => null;

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
