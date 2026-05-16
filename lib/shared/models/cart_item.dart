// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle CartItem (panier client)
// Géré localement (pas de persistance API — le panier est envoyé à la commande)
// ─────────────────────────────────────────────────────────────────────────────
import 'product.dart';

class CartItem {
  final Product product;
  final int quantity;
  final String? note; // instructions spéciales

  const CartItem({
    required this.product,
    required this.quantity,
    this.note,
  });

  double get subtotal => product.price * quantity;
  double get total    => subtotal;
  String get formattedSubtotal => '${subtotal.toStringAsFixed(0)} F';

  static const _keep = Object();

  // FIX: sentinel pour pouvoir effacer la note (note: null)
  CartItem copyWith({int? quantity, Object? note = _keep}) => CartItem(
    product:  product,
    quantity: quantity ?? this.quantity,
    note:     note == _keep ? this.note : note as String?,
  );

  Map<String, dynamic> toOrderItem() => {
    'productId': product.id,
    'quantity':  quantity,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}
