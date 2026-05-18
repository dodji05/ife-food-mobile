// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — CartProvider (panier client)
//
// Panier en mémoire (StateNotifier). Pas de persistance Hive pour l'instant
// (perte au logout). Single-pro check : refuse ajout silencieux d'items
// d'un pro différent (TIER 2 : remonter via callback + dialog).
//
// Mutations exposées :
//   - addItem(product, professionalId, {quantity})
//   - removeItem(productId)
//   - updateQuantity(productId, qty)
//   - clearCart()
//   - applyPromoCode(code) async → throws si invalide
//   - clearPromo()
//   - reorderFromOrderId(orderId) async → recharge items d'une ancienne order
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';

class CartState {
  final List<CartItem> items;
  final String? professionalId;
  final String? promoCode;
  final double promoDiscount;

  const CartState({
    this.items = const [],
    this.professionalId,
    this.promoCode,
    this.promoDiscount = 0,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  /// Total après application de la réduction promo. Garanti >= 0.
  double get totalAfterPromo => (subtotal - promoDiscount).clamp(0, double.infinity).toDouble();
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
  bool get hasPromo => promoCode != null && promoDiscount > 0;

  /// Sentinel pour permettre d'effacer un champ nullable via copyWith.
  /// Sans ça `promoCode: null` ne se distingue pas de "non fourni".
  static const _keep = Object();

  CartState copyWith({
    List<CartItem>? items,
    Object? professionalId = _keep,
    Object? promoCode      = _keep,
    double? promoDiscount,
  }) => CartState(
    items:          items ?? this.items,
    professionalId: professionalId == _keep ? this.professionalId : professionalId as String?,
    promoCode:      promoCode      == _keep ? this.promoCode      : promoCode      as String?,
    promoDiscount:  promoDiscount  ?? this.promoDiscount,
  );
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(Product product, String professionalId, {int quantity = 1}) {
    if (state.professionalId != null && state.professionalId != professionalId) {
      // Different restaurant — refus silencieux (TIER 2 : remonter callback)
      return;
    }

    final existing = state.items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(quantity: updated[existing].quantity + quantity);
      state = state.copyWith(items: updated, professionalId: professionalId);
    } else {
      state = state.copyWith(
        items: [...state.items, CartItem(product: product, quantity: quantity)],
        professionalId: professionalId,
      );
    }
  }

  void removeItem(String productId) {
    final updated = state.items.where((i) => i.product.id != productId).toList();
    state = state.copyWith(
      items: updated,
      professionalId: updated.isEmpty ? null : state.professionalId,
    );
    // Si on vide le panier, on retire aussi la promo (pas de promo sur panier vide).
    if (updated.isEmpty) clearPromo();
  }

  void updateQuantity(String productId, int qty) {
    if (qty <= 0) { removeItem(productId); return; }
    final updated = state.items.map((i) => i.product.id == productId ? i.copyWith(quantity: qty) : i).toList();
    state = state.copyWith(items: updated);
  }

  void clearCart() {
    state = const CartState();
  }

  bool canAddFrom(String professionalId) =>
    state.professionalId == null || state.professionalId == professionalId;

  // ── Promo code ────────────────────────────────────────────────────────────

  /// Valide un code promo côté backend (read-only, ne consomme pas d'use)
  /// puis applique le discount au state local. Throws `Exception` avec
  /// message backend si le code est invalide / expiré / hors quota.
  ///
  /// Le state est mis à jour seulement en cas de succès. En cas d'erreur,
  /// le code et discount précédents (s'il y en avait) sont conservés.
  Future<void> applyPromoCode(String code) async {
    if (code.trim().isEmpty) {
      throw Exception('Code promo vide');
    }
    if (state.isEmpty) {
      throw Exception('Panier vide — ajoutez des articles avant');
    }
    final res = await ApiClient.instance.post('/promo/validate', data: {
      'code':     code.trim().toUpperCase(),
      'subtotal': state.subtotal,
      'currency': 'XOF',
    });
    final data = res['data'] as Map<String, dynamic>?;
    final valid = data?['valid'] as bool? ?? false;
    if (!valid) {
      throw Exception((data?['message'] as String?) ?? 'Code promo invalide');
    }
    final discount = (data?['discount'] as num?)?.toDouble() ?? 0;
    state = state.copyWith(
      promoCode:     code.trim().toUpperCase(),
      promoDiscount: discount,
    );
  }

  /// Retire le code promo appliqué (utile si user veut le changer ou si
  /// le panier devient vide).
  void clearPromo() {
    state = state.copyWith(promoCode: null, promoDiscount: 0);
  }

  // ── Re-commander ──────────────────────────────────────────────────────────

  /// Recharge le panier depuis une commande existante. Idéal pour le bouton
  /// 'Recommander' de l'historique. Écrase totalement le panier courant
  /// (le caller doit avoir confirmé avant si le panier n'était pas vide).
  ///
  /// Requiert que l'API GET /orders/:id retourne les items avec leur
  /// relation `product` jointe (déjà le cas dans orders.service backend).
  /// Les items dont le product a été supprimé entre temps sont ignorés
  /// silencieusement -- le caller peut afficher un warning si besoin.
  ///
  /// Retourne le nombre d'items effectivement rechargés (utile pour UX).
  Future<int> reorderFromOrderId(String orderId) async {
    final res = await ApiClient.instance.get('/orders/$orderId');
    final orderData = res['data'] as Map<String, dynamic>?;
    if (orderData == null) {
      throw Exception('Commande introuvable');
    }
    final professionalId = orderData['professionalId'] as String?;
    if (professionalId == null) {
      throw Exception('Commande sans professionnel associé');
    }

    final rawItems = (orderData['items'] as List?) ?? [];
    final newItems = <CartItem>[];
    for (final raw in rawItems) {
      if (raw is! Map<String, dynamic>) continue;
      final productMap = raw['product'] as Map<String, dynamic>?;
      if (productMap == null) continue; // produit supprimé entretemps
      try {
        final product = Product.fromJson(productMap);
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        newItems.add(CartItem(product: product, quantity: qty));
      } catch (_) {
        // Parsing produit échoué -> on saute cet item
      }
    }

    if (newItems.isEmpty) {
      throw Exception('Aucun produit de cette commande n\'est encore disponible');
    }

    // Reset complet du panier avec les items de l'ancienne commande.
    // On ne reprend PAS le promoCode de l'ancienne commande -- il pourrait
    // être expiré, déjà utilisé (perUser), ou plafonné.
    state = CartState(
      items: newItems,
      professionalId: professionalId,
    );
    return newItems.length;
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
