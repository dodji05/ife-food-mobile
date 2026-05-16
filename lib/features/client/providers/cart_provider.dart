import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/cart_item.dart';
import '../../../shared/models/product.dart';

class CartState {
  final List<CartItem> items;
  final String? professionalId;
  final String? promoCode;
  final double promoDiscount;

  const CartState({this.items = const [], this.professionalId, this.promoCode, this.promoDiscount = 0});

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;

  CartState copyWith({List<CartItem>? items, String? professionalId, String? promoCode, double? promoDiscount}) =>
    CartState(items: items ?? this.items, professionalId: professionalId ?? this.professionalId,
      promoCode: promoCode ?? this.promoCode, promoDiscount: promoDiscount ?? this.promoDiscount);
}

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addItem(Product product, String professionalId, {int quantity = 1}) {
    if (state.professionalId != null && state.professionalId != professionalId) {
      // Different restaurant — ask to clear cart
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
    state = state.copyWith(items: updated, professionalId: updated.isEmpty ? null : state.professionalId);
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
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) => CartNotifier());
