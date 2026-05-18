import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/professional.dart';
import '../../../shared/models/product.dart';

// ── ProOrder (vue professionnel d'une commande) ───────────────────────────────
//
// ⚠️ Modèle UNIFIÉ : enrichi des champs exposés par l'API standalone
// ife-food-pro (clientId/client, driverId/driver, updatedAt, promoCode,
// currency, paymentMethod, estimatedDeliveryMin). Tous nullable ou avec
// defaults — zéro régression côté écrans existants.
class ProOrder {
  // ── Identité ──────────────────────────────────────────────────────────────
  final String  id;
  final String  status;

  // ── Client (refs + objet complet pour avatar/téléphone/etc.) ──────────────
  final String  clientId;
  /// Objet client complet retourné par `include: { client: {...} }`.
  /// Contient `name`, `firstName`, `avatarUrl`, `phone`, etc.
  /// `null` si l'API n'inclut pas la relation.
  final Map<String, dynamic>? client;

  // ── Driver (optionnel — assigné après READY_FOR_PICKUP) ───────────────────
  final String? driverId;
  /// Objet driver complet (avatar, téléphone, nom). `null` tant que pas assigné.
  final Map<String, dynamic>? driver;

  // ── Items & montants ──────────────────────────────────────────────────────
  final List<OrderItem> items;
  final double  subtotal;
  final double  deliveryFee;
  final double  commissionAmount;
  /// Montant total facturé au client (= subtotal + deliveryFee − promoDiscount).
  /// Persisté par le backend, fallback calculé si absent.
  final double  totalAmount;

  // ── Livraison ─────────────────────────────────────────────────────────────
  final String  deliveryAddress;
  final String? specialInstructions;
  final int?    estimatedDeliveryMin;

  // ── Paiement & promo ──────────────────────────────────────────────────────
  /// Devise. Défaut `XOF`. Override par produit/commande si multi-devise.
  final String  currency;
  /// Méthode de paiement (`STRIPE` | `KKIAPAY` | `MTN_MOMO` | `CASH` | …).
  final String  paymentMethod;
  final String? promoCode;

  // ── Timestamps ────────────────────────────────────────────────────────────
  final DateTime createdAt;
  /// Date de dernière mise à jour serveur. Utile pour le tri "récent" et
  /// le refresh logic (ne re-fetch que si updatedAt change).
  final DateTime updatedAt;

  /// Nom client aplati renvoyé par certains endpoints legacy (`clientName`
  /// directement à la racine, sans relation `client` incluse). Sert de
  /// fallback dans le getter `clientName` quand la Map `client` est `null`.
  final String? _flatClientName;

  const ProOrder({
    required this.id,
    required this.status,
    required this.clientId,
    this.client,
    this.driverId,
    this.driver,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.commissionAmount,
    required this.totalAmount,
    required this.deliveryAddress,
    this.specialInstructions,
    this.estimatedDeliveryMin,
    this.currency      = 'XOF',
    this.paymentMethod = 'STRIPE',
    this.promoCode,
    required this.createdAt,
    required this.updatedAt,
    String? flatClientName,
  }) : _flatClientName = flatClientName;

  factory ProOrder.fromJson(Map<String, dynamic> j) {
    final clientMap = j['client'] as Map<String, dynamic>?;
    final driverMap = j['driver'] as Map<String, dynamic>?;
    final subtotal    = (j['subtotal']         as num?)?.toDouble() ?? 0.0;
    final deliveryFee = (j['deliveryFee']      as num?)?.toDouble() ?? 0.0;
    // Backend Prisma → totalAmount ; fallback sur `total` ou calcul.
    final total       = ((j['totalAmount'] as num?) ?? (j['total'] as num?))?.toDouble()
                        ?? (subtotal + deliveryFee);
    return ProOrder(
      id:               j['id']             as String? ?? '',
      status:           j['status']         as String? ?? 'PENDING',
      clientId:         j['clientId']       as String? ?? '',
      client:           clientMap,
      driverId:         j['driverId']       as String?,
      driver:           driverMap,
      items: (j['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((i) => OrderItem.fromJson(i))
          .toList(),
      subtotal:         subtotal,
      deliveryFee:      deliveryFee,
      commissionAmount: (j['commissionAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount:      total,
      deliveryAddress:  j['deliveryAddress']     as String? ?? '',
      specialInstructions: j['specialInstructions'] as String?,
      estimatedDeliveryMin: (j['estimatedDeliveryMin'] as num?)?.toInt(),
      currency:         j['currency']           as String? ?? 'XOF',
      paymentMethod:    j['paymentMethod']      as String? ?? 'STRIPE',
      promoCode:        j['promoCode']          as String?,
      createdAt:        DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:        DateTime.tryParse(j['updatedAt'] as String? ?? '')
                        ?? DateTime.tryParse(j['createdAt'] as String? ?? '')
                        ?? DateTime.now(),
      flatClientName:   j['clientName']         as String?,
    );
  }

  // ── Helpers client ────────────────────────────────────────────────────────
  /// Nom à afficher : préfère `client.name` (relation incluse), retombe sur
  /// `client.firstName`, puis sur le champ aplati `clientName` (legacy),
  /// enfin `'Client'`.
  String get clientName {
    final fromMap = client?['name'] ?? client?['firstName'];
    if (fromMap is String && fromMap.isNotEmpty) return fromMap;
    if (_flatClientName != null && _flatClientName!.isNotEmpty) {
      return _flatClientName!;
    }
    return 'Client';
  }

  /// URL avatar du client (si l'API a inclus la relation).
  String? get clientAvatarUrl => client?['avatarUrl'] as String?;

  /// Téléphone client (pour bouton "Appeler" depuis l'écran commande).
  String? get clientPhone => client?['phone'] as String?;

  // ── Helpers driver ────────────────────────────────────────────────────────
  // Le backend Prisma renvoie `driver.user.{name, firstName, phone, avatarUrl}`
  // (relation Driver -> User). On lit d'abord depuis driver.user, puis fallback
  // sur driver.* pour les éventuels endpoints qui aplatissent la réponse.
  Map<String, dynamic>? get _driverUser =>
      driver?['user'] as Map<String, dynamic>?;

  String? get driverName {
    final n = _driverUser?['name']
           ?? _driverUser?['firstName']
           ?? driver?['name']
           ?? driver?['firstName'];
    return n is String ? n : null;
  }
  String? get driverPhone =>
      (_driverUser?['phone'] ?? driver?['phone']) as String?;

  String? get driverAvatarUrl =>
      (_driverUser?['avatarUrl'] ?? driver?['avatarUrl']) as String?;

  // ── Helpers statut ────────────────────────────────────────────────────────
  /// Commande venant d'être payée, en attente d'acceptation par le pro.
  bool get isPending => status == 'PAID';

  /// Commande active côté pro (acceptée → prête, à traiter).
  bool get isActive =>
      ['ACCEPTED', 'IN_PREPARATION', 'READY_FOR_PICKUP'].contains(status);

  /// Commande prête mais attend un livreur.
  bool get needsDriver => status == 'READY_FOR_PICKUP';

  /// Commande terminée (livrée ou annulée).
  bool get isClosed => status == 'DELIVERED' || status == 'CANCELLED';

  String get statusLabel => switch (status) {
    'PENDING_PAYMENT'  => 'En attente de paiement',
    'PAID'             => 'Nouvelle commande',
    'ACCEPTED'         => 'Acceptée',
    'IN_PREPARATION'   => 'En préparation',
    'READY_FOR_PICKUP' => 'Prête',
    'DRIVER_ASSIGNED'  => 'Livreur assigné',
    'IN_DELIVERY'      => 'En livraison',
    'DELIVERED'        => 'Livrée',
    'CANCELLED'        => 'Annulée',
    _                  => status,
  };

  // ── Helpers montants ──────────────────────────────────────────────────────
  /// Revenu net du pro après déduction commission plateforme.
  double get netRevenue => subtotal - commissionAmount;

  String get formattedTotal {
    final t = totalAmount.toStringAsFixed(0);
    return currency == 'XOF' ? '$t F' : '$t $currency';
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final liveOrdersProvider = FutureProvider.autoDispose
    .family<List<ProOrder>, String>((ref, status) async {
  // Backend : GET /orders/professional (le filtre status n'est pas géré par
  // l'endpoint, on filtre côté client en attendant un query param dédié).
  final res = await ApiClient.instance.get('/orders/professional');
  final list = res['data'] as List? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .where((e) => e['status'] == status)
      .map(ProOrder.fromJson)
      .toList();
});

/// Liste des catégories du pro courant, triées par sortOrder croissant.
/// Le backend GET /products/categories/:proId inclut les products mais on
/// les ignore ici — la liste produits vient du `productsProvider`.
final categoriesProvider = FutureProvider.autoDispose<List<ProductCategory>>((ref) async {
  final me = await ApiClient.instance.get('/professionals/me');
  final proId = (me['data'] as Map<String, dynamic>?)?['id'] as String?;
  if (proId == null) return [];
  final res = await ApiClient.instance.get('/products/categories/$proId');
  final list = res['data'] as List? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(ProductCategory.fromJson)
      .toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  // /professionals/me/products n'existe pas. On passe par /professionals/me
  // pour récupérer l'id puis on appelle /products/professional/:id (public).
  final me = await ApiClient.instance.get('/professionals/me');
  final proId = (me['data'] as Map<String, dynamic>?)?['id'] as String?;
  if (proId == null) return [];
  final res = await ApiClient.instance.get('/products/professional/$proId');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
});

final reviewsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  // /professionals/me/reviews n'existe pas. On passe par /reviews/professional/:id.
  final me = await ApiClient.instance.get('/professionals/me');
  final proId = (me['data'] as Map<String, dynamic>?)?['id'] as String?;
  if (proId == null) return {};
  final res = await ApiClient.instance.get('/reviews/professional/$proId');
  // Le contrôleur renvoie une liste — on l'enveloppe pour conserver la signature.
  final data = res['data'];
  if (data is List) return {'reviews': data};
  return (data as Map<String, dynamic>?) ?? {};
});

final dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.get('/professionals/me/dashboard');
  return res['data'] as Map<String, dynamic>? ?? {};
});

// ── ProState / ProNotifier ────────────────────────────────────────────────────
class ProState {
  final Professional? professional;
  final bool isLoading;
  final String? error;

  const ProState({this.professional, this.isLoading = false, this.error});

  ProState copyWith({Professional? professional, bool? isLoading, String? error}) =>
      ProState(
        professional: professional ?? this.professional,
        isLoading:    isLoading    ?? this.isLoading,
        error:        error        ?? this.error,
      );
}

class ProNotifier extends StateNotifier<ProState> {
  ProNotifier() : super(const ProState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await ApiClient.instance.get('/professionals/me');
      state = state.copyWith(
          professional: Professional.fromJson(res['data']), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleOpen() async {
    final current = state.professional?.isOpen ?? false;
    // Optimistic update
    state = state.copyWith(
      professional: state.professional?.copyWith(isOpen: !current),
    );
    try {
      await ApiClient.instance.patch('/professionals/me/toggle-open');
    } catch (e) {
      // Rollback on error
      state = state.copyWith(
        professional: state.professional?.copyWith(isOpen: current),
        error: e.toString(),
      );
    }
  }

  /// Met à jour les infos métier du pro (businessName, description, address,
  /// city, phone, email, deliveryRadiusKm…). PATCH /professionals/me.
  /// Refresh le state après succès pour que les écrans abonnés (dashboard,
  /// profile, header) reflètent les nouvelles valeurs immédiatement.
  Future<void> updateProfile(Map<String, dynamic> data) async {
    try {
      await ApiClient.instance.patch('/professionals/me', data: data);
      await _load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  Future<void> updateOpeningHours(Map<String, dynamic> hours) async {
    try {
      // Endpoint dédié — PATCH /professionals/me ne whiteliste pas openingHours.
      await ApiClient.instance.patch('/professionals/me/opening-hours', data: {'openingHours': hours});
      await _load();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> acceptOrder(String id) async {
    try {
      await ApiClient.instance.patch('/orders/$id/status', data: {'status': 'ACCEPTED'});
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> rejectOrder(String id, String reason) async {
    try {
      // Le DTO backend attend `cancelledReason`, pas `reason` (forbidNonWhitelisted).
      await ApiClient.instance.patch('/orders/$id/status',
          data: {'status': 'CANCELLED', 'cancelledReason': reason});
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markInPreparation(String id) async {
    try {
      await ApiClient.instance.patch('/orders/$id/status', data: {'status': 'IN_PREPARATION'});
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markReady(String id) async {
    try {
      await ApiClient.instance.patch('/orders/$id/status', data: {'status': 'READY_FOR_PICKUP'});
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Catalogue mutations ────────────────────────────────────────────────────
  //
  // Stratégie : on n'invalide pas `productsProvider` ici — c'est aux écrans
  // appelants (catalogue, add_product) de le faire après une mutation pour
  // garder un contrôle fin du moment du refresh (animations, snackbars, etc).
  // Toutes ces méthodes lèvent une `Exception` en cas d'erreur réseau pour
  // que le screen affiche un message clair.

  /// Crée une catégorie de produits. `name` est un Map multilingue
  /// `{fr: '...', en: '...'}`. Retourne l'id de la catégorie créée.
  /// Le mobile fournit en général juste {fr: nom} -> le backend complète.
  Future<String> createCategory(Map<String, dynamic> name, {String? icon}) async {
    final res = await ApiClient.instance.post('/products/categories', data: {
      'name': name,
      if (icon != null && icon.isNotEmpty) 'icon': icon,
    });
    final created = res['data'] as Map<String, dynamic>?;
    return created?['id'] as String? ?? '';
  }

  /// Crée un produit côté backend.
  /// `data` doit contenir `name` (Map multilingue), `price`, `currency`,
  /// `isAvailable`, optionnellement `description` (Map) et `stock`.
  /// Retourne l'id du produit créé (utile pour enchaîner avec un upload image).
  Future<String> createProduct(Map<String, dynamic> data) async {
    final res = await ApiClient.instance.post('/products', data: data);
    final created = res['data'] as Map<String, dynamic>?;
    return created?['id'] as String? ?? '';
  }

  /// Met à jour un produit existant. `data` partiel (PATCH).
  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    await ApiClient.instance.patch('/products/$productId', data: data);
  }

  /// Supprime un produit. Le backend doit gérer la soft-delete ou cascade.
  Future<void> deleteProduct(String productId) async {
    await ApiClient.instance.delete('/products/$productId');
  }

  /// Toggle rapide de disponibilité sans repasser par le formulaire complet.
  /// Endpoint dédié `/products/:id/toggle` — fallback PATCH si non supporté.
  Future<bool> toggleProductAvailability(String productId, bool current) async {
    final next = !current;
    try {
      await ApiClient.instance.patch('/products/$productId/toggle');
    } on Exception {
      // Fallback : si l'endpoint dédié n'existe pas côté backend, on tombe
      // sur le PATCH générique. Évite de casser l'UX si l'API évolue.
      await ApiClient.instance.patch('/products/$productId',
          data: {'isAvailable': next});
    }
    return next;
  }

  /// Upload une image pour un produit existant.
  /// Backend : `POST /products/:id/image` avec champ multipart `image`.
  /// Retourne l'URL de l'image hébergée.
  Future<String?> uploadProductImage(String productId, File imageFile) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(imageFile.path, filename: fileName),
    });
    final res = await ApiClient.instance.postForm('/products/$productId/image', form);
    final data = res['data'] as Map<String, dynamic>?;
    return data?['imageUrl'] as String? ?? data?['url'] as String?;
  }
}

final proProvider = StateNotifierProvider<ProNotifier, ProState>(
    (_) => ProNotifier());
