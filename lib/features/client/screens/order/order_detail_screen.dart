import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/order.dart';

final orderDetailProvider = FutureProvider.autoDispose.family<Order, String>((ref, id) async {
  final res = await ApiClient.instance.get('/orders/$id');
  return Order.fromJson(res['data']);
});

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
  Timer? _pollTimer;
  DateTime? _pollStart;
  bool _checking = false;

  static const _pollInterval   = Duration(seconds: 3);
  static const _maxPollMinutes = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Refresh immédiat quand l'utilisateur revient dans l'app depuis FedaPay.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(orderDetailProvider(widget.orderId));
    }
  }

  void _startPolling() {
    if (_pollTimer?.isActive == true) return;
    _pollStart = DateTime.now();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (_pollStart != null &&
          DateTime.now().difference(_pollStart!) > _maxPollMinutes) {
        _stopPolling();
        return;
      }
      ref.invalidate(orderDetailProvider(widget.orderId));
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(title: const Text('Détail de la commande'), leading: const BackButton()),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (o) {
          // Démarre le polling tant que le paiement n'est pas confirmé,
          // l'arrête dès que le webhook a mis à jour le statut.
          if (o.paymentStatus == 'PENDING') {
            _startPolling();
          } else {
            _stopPolling();
          }
          return ListView(padding: const EdgeInsets.all(16), children: [
            // Bandeau "en attente de confirmation paiement"
            if (o.paymentStatus == 'PENDING') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'En attente de confirmation du paiement…',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                            fontWeight: FontWeight.w700, color: AppColors.warning),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _checking ? null : () async {
                        setState(() => _checking = true);
                        try {
                          final res = await ApiClient.instance.post(
                            '/payments/${widget.orderId}/check',
                          );
                          final status = res['data']?['status'] as String? ?? 'PENDING';
                          if (status == 'SUCCESS') {
                            ref.invalidate(orderDetailProvider(widget.orderId));
                          } else if (status == 'FAILED') {
                            ref.invalidate(orderDetailProvider(widget.orderId));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Paiement refusé ou annulé.'),
                                backgroundColor: Colors.red,
                              ));
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Paiement toujours en attente de confirmation.'),
                              ));
                            }
                          }
                        } catch (_) {
                          ref.invalidate(orderDetailProvider(widget.orderId));
                        } finally {
                          if (mounted) setState(() => _checking = false);
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: const BorderSide(color: AppColors.warning),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _checking
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                          : const Text(
                              'J\'ai payé — Vérifier le statut',
                              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                    ),
                  ),
                ]),
              ),
            ],
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
              // Guard length : si l'ID fait moins de 8 chars (edge case),
              // .substring(0,8) lance RangeError. On affiche l'ID complet
              // dans ce cas.
              Text('Commande #${(o.id.length >= 8 ? o.id.substring(0, 8) : o.id).toUpperCase()}',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8))),
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
            if (o.tipAmount > 0) _Row('Pourboire livreur 🎁', '${o.tipAmount.toStringAsFixed(0)} F', color: AppColors.warning),
            const Divider(height: 20),
            _Row('Total', '${o.totalAmount.toStringAsFixed(0)} F', bold: true),
          ])),
          const SizedBox(height: 12),

          // CTAs post-livraison : avis + pourboire
          if (o.isDelivered) ...[
            if (!o.hasReview) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/order/${o.id}/review'),
                  icon: const Icon(Icons.star_rounded, size: 18),
                  label: const Text('Laisser un avis',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (o.tipAmount == 0) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/order/${o.id}/tip'),
                  icon: const Text('🎁', style: TextStyle(fontSize: 16)),
                  label: const Text('Laisser un pourboire au livreur',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: const BorderSide(color: AppColors.warning),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],

          // Delivery info
          _Card(title: '📍 Livraison', child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.deliveryAddress, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textSecondary)),
            if (o.estimatedDeliveryMin != null) ...[
              const SizedBox(height: 8),
              Text('Estimation : ${o.estimatedDeliveryMin}-${o.estimatedDeliveryMin! + 15} min',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
            ],
          ])),
          const SizedBox(height: 40),
        ]);
        },
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
    decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor.withOpacity(0.8))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: context.textMuted, letterSpacing: 0.5)),
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
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textMuted, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
      const Spacer(),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: bold ? 16 : 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? (bold ? context.textPrimary : context.textSecondary))),
    ]),
  );
}
