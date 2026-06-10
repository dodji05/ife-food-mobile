import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/order.dart';
import '../../providers/cart_provider.dart';
import '../../../../core/utils/invoice_generator.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final res = await ApiClient.instance.get('/orders/my-orders', params: {'limit': '50'});
  final raw = res['data'];
  final list = raw is List ? raw : (raw is Map ? (raw['data'] as List? ?? []) : []);
  return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
});

/// Filtres possibles sur l'historique commandes. 'all' = aucun filtre.
enum _OrderFilter { all, active, delivered, cancelled }

extension _OrderFilterLabel on _OrderFilter {
  String get label => switch (this) {
    _OrderFilter.all       => 'Toutes',
    _OrderFilter.active    => 'En cours',
    _OrderFilter.delivered => 'Livrées',
    _OrderFilter.cancelled => 'Annulées',
  };

  /// Prédicat pour filtrer la liste retournée par /orders/my-orders.
  bool matches(Order o) => switch (this) {
    _OrderFilter.all       => true,
    _OrderFilter.active    => o.isActive,
    _OrderFilter.delivered => o.isDelivered,
    _OrderFilter.cancelled => o.isCancelled,
  };
}

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  // L'index du tab courant détermine le filtre via _OrderFilter.values[i].

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Mes commandes'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600, fontSize: 13),
          tabs: orders.maybeWhen(
            data: (list) => _OrderFilter.values.map((f) {
              // Badge avec count par filtre (pour montrer 'Livrées (3)' p. ex.)
              final count = list.where(f.matches).length;
              return Tab(text: count > 0 ? '${f.label} ($count)' : f.label);
            }).toList(),
            orElse: () => _OrderFilter.values.map((f) => Tab(text: f.label)).toList(),
          ),
        ),
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) => list.isEmpty
            ? _emptyHome(context)
            : TabBarView(
                controller: _tabs,
                children: _OrderFilter.values.map((f) {
                  final filtered = list.where(f.matches).toList();
                  if (filtered.isEmpty) return _emptyFilter(f);
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(ordersProvider),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OrderCard(order: filtered[i]),
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }

  /// État vide global (aucune commande tout court) — incite à passer commande.
  Widget _emptyHome(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📦', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 12),
      Text('Aucune commande',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
            fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 8),
      Text('Vos commandes apparaîtront ici',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: context.textMuted)),
      const SizedBox(height: 24),
      ElevatedButton.icon(
        onPressed: () => context.go('/home'),
        icon: const Icon(Icons.explore_rounded),
        label: const Text('Commander'),
        style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48)),
      ),
    ]),
  );

  /// État vide par tab (ex: 'Aucune commande en cours').
  Widget _emptyFilter(_OrderFilter f) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_iconForEmptyFilter(f), size: 56, color: context.textMuted),
        const SizedBox(height: 12),
        Text('Aucune commande ${f.label.toLowerCase()}',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w700, color: context.textPrimary)),
      ]),
    ),
  );

  IconData _iconForEmptyFilter(_OrderFilter f) => switch (f) {
    _OrderFilter.active    => Icons.delivery_dining_rounded,
    _OrderFilter.delivered => Icons.check_circle_outline_rounded,
    _OrderFilter.cancelled => Icons.cancel_outlined,
    _OrderFilter.all       => Icons.receipt_long_rounded,
  };
}

class _OrderCard extends ConsumerStatefulWidget {
  final Order order;
  const _OrderCard({required this.order});
  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  bool _reordering = false;
  bool _generatingInvoice = false;

  Color get _statusColor {
    if (widget.order.isDelivered) return AppColors.success;
    if (widget.order.isCancelled) return AppColors.error;
    if (widget.order.isActive) return AppColors.primary;
    return context.textMuted;
  }

  /// Recharge les items dans le panier puis push /cart. Confirme via dialog
  /// si le panier contient déjà des items (d'un autre pro typiquement).
  Future<void> _reorder() async {
    final cart = ref.read(cartProvider);

    // Si panier non vide, demander confirmation avant d'écraser
    if (!cart.isEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Vider le panier ?'),
          content: const Text(
            'Votre panier actuel sera remplacé par les articles de cette commande.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _reordering = true);
    try {
      final count = await ref.read(cartProvider.notifier).reorderFromOrderId(widget.order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count article${count > 1 ? 's' : ''} rechargé${count > 1 ? 's' : ''} dans le panier'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
      context.push('/cart');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _downloadInvoice() async {
    setState(() => _generatingInvoice = true);
    try {
      await generateAndShareInvoice(widget.order);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Erreur lors de la génération du reçu'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _generatingInvoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return GestureDetector(
      onTap: () => context.push('/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor.withOpacity(0.8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Logo restaurant
            Container(
              width: 44, height: 44,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(10),
                image: order.professionalLogoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(order.professionalLogoUrl!),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: order.professionalLogoUrl == null
                  ? Icon(Icons.storefront_rounded, color: context.textMuted, size: 22)
                  : null,
            ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  order.professionalName.isNotEmpty ? order.professionalName : 'Restaurant',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                      fontWeight: FontWeight.w800, color: context.textPrimary))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(order.statusLabel,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                        fontWeight: FontWeight.w700, color: _statusColor)),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${order.totalAmount.toStringAsFixed(0)} F',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
              const SizedBox(height: 2),
              Text(
                '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}  ${order.createdAt.hour.toString().padLeft(2, '0')}h${order.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
            ])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Spacer(),
            // Bouton facture (dès que le paiement est confirmé)
            if (order.isPaid) ...[
              OutlinedButton.icon(
                onPressed: _generatingInvoice ? null : _downloadInvoice,
                icon: _generatingInvoice
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.receipt_long_rounded, size: 14),
                label: const Text('Reçu',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Bouton avis (livré, pas encore d'avis)
            if (order.isDelivered && !order.hasReview) ...[
              OutlinedButton.icon(
                onPressed: () => context.push('/order/${order.id}/review'),
                icon: const Icon(Icons.star_rounded, size: 14),
                label: const Text('Avis', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(80, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (order.isDelivered) OutlinedButton(
              onPressed: _reordering ? null : _reorder,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(110, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                side: const BorderSide(color: AppColors.primary),
              ),
              child: _reordering
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Text('Recommander', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
            ),
            if (order.isActive) ElevatedButton(
              onPressed: () => context.push('/tracking/${order.id}'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 32),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Suivre', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
            ),
          ]),
        ]),
      ),
    );
  }
}
