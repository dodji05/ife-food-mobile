// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — Mission model
// MODIFIÉ : ajout de deliveryId et activeStep au niveau du modèle
//            (auparavant stockés uniquement dans DriverState)
// ─────────────────────────────────────────────────────────────────────────────

class Mission {
  final String orderId;
  final String professionalName;
  final String professionalAddress;
  final double professionalLat, professionalLng;
  final String clientAddress;
  final double clientLat, clientLng;
  final double deliveryFee;
  final String currency;
  final double distanceKm;
  final int estimatedMinutes;
  final String orderStatus;      // statut de la commande (DRIVER_ASSIGNED, etc.)
  final String deliveryStatus;   // statut de la livraison (ASSIGNED, HEADING_TO_PICKUP, etc.)
  final DateTime createdAt;
  final List<MissionItem> items;

  const Mission({
    required this.orderId,
    required this.professionalName,
    required this.professionalAddress,
    required this.professionalLat,
    required this.professionalLng,
    required this.clientAddress,
    required this.clientLat,
    required this.clientLng,
    required this.deliveryFee,
    this.currency        = 'XOF',
    this.distanceKm      = 0,
    this.estimatedMinutes = 20,
    required this.orderStatus,
    this.deliveryStatus  = 'ASSIGNED',
    required this.createdAt,
    this.items           = const [],
  });

  // Depuis un Order (payload de la notification initiale)
  factory Mission.fromOrderJson(Map<String, dynamic> json) {
    final pro = json['professional'] as Map<String, dynamic>? ?? {};
    return Mission(
      orderId:             json['id'] ?? json['orderId'] ?? '',
      professionalName:    pro['businessName'] ?? json['professionalName'] ?? 'Restaurant',
      professionalAddress: pro['address']      ?? json['professionalAddress'] ?? '',
      professionalLat:     (pro['lat']         ?? json['professionalLat'] ?? 0).toDouble(),
      professionalLng:     (pro['lng']         ?? json['professionalLng'] ?? 0).toDouble(),
      clientAddress:       json['deliveryAddress'] ?? '',
      clientLat:           (json['deliveryLat']    ?? 0).toDouble(),
      clientLng:           (json['deliveryLng']    ?? 0).toDouble(),
      deliveryFee:         (json['deliveryFee']    ?? 0).toDouble(),
      currency:            json['currency'] ?? 'XOF',
      distanceKm:          (json['distanceKm']      ?? 0).toDouble(),
      estimatedMinutes:    json['estimatedDeliveryMin'] ?? 20,
      orderStatus:         json['status'] ?? 'DRIVER_ASSIGNED',
      deliveryStatus:      json['delivery']?['status'] ?? 'ASSIGNED',
      createdAt:           DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      items: (json['items'] as List? ?? []).map((i) => MissionItem.fromJson(i)).toList(),
    );
  }

  // Depuis une Delivery (réponse de GET /drivers/me/active-missions)
  factory Mission.fromDeliveryJson(Map<String, dynamic> json) {
    final order = json['order'] as Map<String, dynamic>? ?? {};
    return Mission.fromOrderJson({
      ...order,
      'delivery': { 'status': json['status'] },
    });
  }

  // Crée une copie avec un nouveau deliveryStatus
  Mission withStep(String step) => Mission(
    orderId: orderId, professionalName: professionalName,
    professionalAddress: professionalAddress, professionalLat: professionalLat,
    professionalLng: professionalLng, clientAddress: clientAddress,
    clientLat: clientLat, clientLng: clientLng, deliveryFee: deliveryFee,
    currency: currency, distanceKm: distanceKm, estimatedMinutes: estimatedMinutes,
    orderStatus: orderStatus, deliveryStatus: step, createdAt: createdAt, items: items,
  );

  bool get isPickupPhase => const [
    'ASSIGNED', 'HEADING_TO_PICKUP', 'ARRIVED_AT_PICKUP'
  ].contains(deliveryStatus);

  bool get isDeliveryPhase => const [
    'PICKED_UP', 'IN_DELIVERY'
  ].contains(deliveryStatus);

  bool get isCompleted => deliveryStatus == 'DELIVERED';

  String get shortAddress {
    if (clientAddress.length <= 35) return clientAddress;
    return '${clientAddress.substring(0, 35)}…';
  }
}

class MissionItem {
  final String productName;
  final int quantity;
  final double unitPrice;

  const MissionItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory MissionItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>? ?? {};
    final name    = product['name'] as Map<String, dynamic>? ?? {};
    return MissionItem(
      productName: name['fr'] ?? name['en'] ?? 'Produit',
      quantity:    json['quantity'] ?? 1,
      unitPrice:   (json['unitPrice'] ?? 0).toDouble(),
    );
  }
}

class DeliveryStep {
  final String id, label, description;
  final String status; // 'done' | 'active' | 'pending'
  final DateTime? timestamp;

  const DeliveryStep({
    required this.id, required this.label, required this.description,
    required this.status, this.timestamp,
  });
}
