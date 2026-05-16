import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order.dart';

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((ref, id) async {
  final res = await ApiClient.instance.get('/orders/$id');
  return Order.fromJson(res['data']);
});

class OrderDetailScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderDetailProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Détail de la commande'), leading: const BackButton()),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (o) => ListView(padding: const EdgeInsets.all(16), children: [
          // Status card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.statusLabel, style: const TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text('Commande #${o.id.substring(0, 8).toUpperCase()}', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8))),
              if (o.isActive) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/tracking/${o.id}'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary, minimumSize: const Size(0, 40)),
                  icon: const Icon(Icons.location_on_rounded, size: 18),
                  label: const Text('Suivre en temps réel', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),

          // Items
          _Card(title: 'Articles commandés', child: Column(
            children: o.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Text('${item.quantity}×', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.primary)),
                const SizedBox(width: 8),
                Expanded(child: Text(item.product?['name']?['fr'] ?? 'Produit', style: const TextStyle(fontFamily: 'Nunito', fontSize: 14))),
                Text('${item.totalPrice.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14)),
              ]),
            )).toList(),
          )),
          const SizedBox(height: 12),

          // Totals
          _Card(title: 'Résumé', child: Column(children: [
            _Row('Sous-total', '${o.subtotal.toStringAsFixed(0)} F'),
            _Row('Livraison', '${o.deliveryFee.toStringAsFixed(0)} F'),
            if (o.promoDiscount > 0) _Row('Réduction', '-${o.promoDiscount.toStringAsFixed(0)} F', color: AppColors.success),
            const Divider(height: 20),
            _Row('Total', '${o.totalAmount.toStringAsFixed(0)} F', bold: true),
          ])),
          const SizedBox(height: 12),

          // Delivery info
          _Card(title: '📍 Livraison', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.deliveryAddress, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkGrey)),
            if (o.estimatedDeliveryMin != null) ...[
              const SizedBox(height: 8),
              Text('Estimation : ${o.estimatedDeliveryMin}-${o.estimatedDeliveryMin! + 15} min',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
            ],
          ])),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title; final Widget child;
  const _Card({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey, letterSpacing: 0.5)),
      const SizedBox(height: 12), child,
    ]),
  );
}

class _Row extends StatelessWidget {
  final String label, value; final bool bold; final Color? color;
  const _Row(this.label, this.value, {this.bold = false, this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? (bold ? AppColors.nearBlack : AppColors.darkGrey))),
    ]),
  );
}
