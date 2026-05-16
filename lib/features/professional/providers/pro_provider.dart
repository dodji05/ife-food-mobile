import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/professional.dart';
import '../../../shared/models/product.dart';

// ── ProOrder (vue professionnel d'une commande) ───────────────────────────────
class ProOrder {
  final String  id;
  final String  status;
  final String  clientName;
  final List<OrderItem> items;
  final double  subtotal;
  final double  deliveryFee;
  final double  commissionAmount;
  final String  deliveryAddress;
  final String? specialInstructions;
  final DateTime createdAt;

  const ProOrder({
    required this.id,
    required this.status,
    required this.clientName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.commissionAmount,
    required this.deliveryAddress,
    this.specialInstructions,
    required this.createdAt,
  });

  factory ProOrder.fromJson(Map<String, dynamic> j) => ProOrder(
    id:                  j['id']                  as String? ?? '',
    status:              j['status']              as String? ?? 'PENDING',
    clientName:          j['clientName']          as String?
                         ?? (j['client'] as Map<String, dynamic>?)?['name'] as String?
                         ?? 'Client',
    items: (j['items'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map((i) => OrderItem.fromJson(i))
        .toList(),
    subtotal:           (j['subtotal']           as num?)?.toDouble() ?? 0.0,
    deliveryFee:        (j['deliveryFee']         as num?)?.toDouble() ?? 0.0,
    commissionAmount:   (j['commissionAmount']    as num?)?.toDouble() ?? 0.0,
    deliveryAddress:     j['deliveryAddress']     as String? ?? '',
    specialInstructions: j['specialInstructions'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] ?? '') ?? DateTime.now(),
  );

  double get totalAmount => subtotal + deliveryFee;

  String get statusLabel => switch (status) {
    'PENDING_PAYMENT' => 'En attente de paiement',
    'PAID'            => 'Nouvelle commande',
    'ACCEPTED'        => 'Acceptée',
    'IN_PREPARATION'  => 'En préparation',
    'READY_FOR_PICKUP'=> 'Prête',
    'IN_DELIVERY'     => 'En livraison',
    'DELIVERED'       => 'Livrée',
    'CANCELLED'       => 'Annulée',
    _                 => status,
  };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final liveOrdersProvider = FutureProvider.autoDispose
    .family<List<ProOrder>, String>((ref, status) async {
  final res = await ApiClient.instance.get('/orders', params: {'status': status});
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(ProOrder.fromJson).toList();
});

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final res = await ApiClient.instance.get('/professionals/me/products');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(Product.fromJson).toList();
});

final reviewsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.instance.get('/professionals/me/reviews');
  return res['data'] as Map<String, dynamic>? ?? {};
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

  Future<void> updateOpeningHours(Map<String, dynamic> hours) async {
    try {
      await ApiClient.instance.patch('/professionals/me', data: {'openingHours': hours});
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
      await ApiClient.instance.patch('/orders/$id/status', data: {'status': 'CANCELLED', 'reason': reason});
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
}

final proProvider = StateNotifierProvider<ProNotifier, ProState>(
    (_) => ProNotifier());
