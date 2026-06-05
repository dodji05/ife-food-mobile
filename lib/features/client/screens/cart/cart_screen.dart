import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/cart_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final fmt  = ref.watch(currencyFormatterProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Mon Panier'),
        leading: const BackButton(),
        actions: [
          if (!cart.isEmpty) TextButton(onPressed: () => ref.read(cartProvider.notifier).clearCart(), child: const Text('Vider', style: TextStyle(color: AppColors.error, fontFamily: 'Nunito', fontWeight: FontWeight.w700))),
        ],
      ),
      bottomNavigationBar: cart.isEmpty ? null : SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: context.cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4))],
          ),
          child: ElevatedButton(
            onPressed: () => context.push('/checkout'),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Passer la commande'),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text(fmt.format(cart.totalAfterPromo), style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13))),
            ]),
          ),
        ),
      ),
      body: cart.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('🛒', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Votre panier est vide', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 8),
            Text('Ajoutez des produits depuis un établissement', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(onPressed: () => context.go('/home'), icon: const Icon(Icons.explore_rounded), label: const Text('Explorer'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
          ]))
        : ListView(padding: const EdgeInsets.all(16), children: [
              // Items
              ...cart.items.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor.withOpacity(0.8))),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
                    child: item.product.imageUrl != null
                      ? Image.network(
                          item.product.imageUrl!,
                          width: 80, height: 80, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 80, height: 80, color: context.bgColor,
                            child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 30)))),
                        )
                      : Container(width: 80, height: 80, color: context.bgColor, child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 30)))),
                  ),
                  Expanded(child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.product.localizedName('fr'), style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${fmt.format(item.product.price)} / unité',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        // Qty controls
                        Row(children: [
                          GestureDetector(onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1),
                            child: Container(width: 28, height: 28, decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.remove_rounded, size: 16))),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text('${item.quantity}', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15))),
                          GestureDetector(onTap: () => ref.read(cartProvider.notifier).addItem(item.product, cart.professionalId!),
                            child: Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.add_rounded, size: 16, color: Colors.white))),
                        ]),
                        const Spacer(),
                        Text(fmt.format(item.total),
                          style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ]),
                    ]),
                  )),
                ]),
              )).toList(),

              const SizedBox(height: 16),

              // Promo code (widget stateful pour gérer controller + loading)
              const _PromoCodeRow(),

              const SizedBox(height: 16),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor.withOpacity(0.8))),
                child: Column(children: [
                  _SummaryRow(label: 'Sous-total', value: fmt.format(cart.subtotal)),
                  const SizedBox(height: 8),
                  // Livraison : montant exact calculé seulement après saisie
                  // de l'adresse au checkout (besoin coords delivery vs pro).
                  // On affiche un placeholder + note explicative.
                  const _SummaryRow(label: 'Livraison', value: 'Calculé à la commande'),
                  if (cart.hasPromo) ...[
                    const SizedBox(height: 8),
                    _SummaryRow(
                      label: 'Code promo (${cart.promoCode})',
                      value: '-${fmt.format(cart.promoDiscount)}',
                      valueColor: AppColors.success,
                    ),
                  ],
                  const Divider(height: 20),
                  // Total estimé HORS livraison. Le total final s'affiche au
                  // checkout (cf checkout_screen.dart) une fois la livraison
                  // calculée côté backend (POST /orders renvoie deliveryFee).
                  _SummaryRow(
                    label: 'Sous-total après promo',
                    value: fmt.format(cart.totalAfterPromo),
                    isBold: true,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text('+ frais de livraison',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
                  ),
                ]),
              ),
            const SizedBox(height: 16),
          ]),
    );
  }
}

// ── Ligne code promo (stateful pour gérer controller + loading) ────────────
class _PromoCodeRow extends ConsumerStatefulWidget {
  const _PromoCodeRow();
  @override
  ConsumerState<_PromoCodeRow> createState() => _PromoCodeRowState();
}

class _PromoCodeRowState extends ConsumerState<_PromoCodeRow> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _apply() async {
    if (_ctrl.text.trim().isEmpty || _loading) return;
    setState(() => _loading = true);
    try {
      await ref.read(cartProvider.notifier).applyPromoCode(_ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Code promo appliqué ✓'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final fmt  = ref.watch(currencyFormatterProvider);

    // Si une promo est déjà appliquée -> affichage "chip" avec bouton retirer.
    if (cart.hasPromo) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cart.promoCode!,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
                  fontWeight: FontWeight.w900, color: AppColors.success)),
            Text('-${fmt.format(cart.promoDiscount)} sur votre commande',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
          ])),
          IconButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearPromo();
              _ctrl.clear();
            },
            icon: Icon(Icons.close_rounded, color: context.textMuted, size: 18),
            tooltip: 'Retirer le code',
          ),
        ]),
      );
    }

    // Sinon : input + bouton Appliquer.
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor.withOpacity(0.8)),
      ),
      child: Row(children: [
        const SizedBox(width: 16),
        const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 20),
        Expanded(child: TextField(
          controller: _ctrl,
          textCapitalization: TextCapitalization.characters,
          enabled: !_loading,
          decoration: const InputDecoration(
            hintText: 'Code promo', border: InputBorder.none,
            enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700),
          onSubmitted: (_) => _apply(),
        )),
        TextButton(
          onPressed: _loading ? null : _apply,
          child: _loading
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : const Text('Appliquer'),
        ),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value; final bool isBold; final Color? valueColor;
  const _SummaryRow({required this.label, required this.value, this.isBold = false, this.valueColor});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textMuted, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
    const Spacer(),
    Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: isBold ? 16 : 14, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
      color: valueColor ?? (isBold ? context.textPrimary : context.textSecondary))),
  ]);
}
