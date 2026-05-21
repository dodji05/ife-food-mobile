import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order.dart';
import '../../providers/cart_provider.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final res = await ApiClient.instance.get('/orders/my-orders');
  // Backend returns paginated { data: [...], meta: {...} }.
  // TransformInterceptor wraps to { success, data: { data: [...], meta: {...} } }.
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
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Mes commandes'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.darkGrey,
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
      const Text('Aucune commande',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
      const SizedBox(height: 8),
      const Text('Vos commandes apparaîtront ici',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey)),
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
        Icon(_iconForEmptyFilter(f), size: 56, color: AppColors.grey),
        const SizedBox(height: 12),
        Text('Aucune commande ${f.label.toLowerCase()}',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
              fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
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

  Color get _statusColor {
    if (widget.order.isDelivered) return AppColors.success;
    if (widget.order.isCancelled) return AppColors.error;
    if (widget.order.isActive) return AppColors.primary;
    return AppColors.grey;
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

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return GestureDetector(
      onTap: () => context.push('/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightGrey.withOpacity(0.8)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(order.professional?['businessName'] ?? 'Restaurant',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w800, color: AppColors.nearBlack))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(order.statusLabel,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    fontWeight: FontWeight.w700, color: _statusColor)),
            ),
          ]),
          const SizedBox(height: 6),
          Text('${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${order.totalAmount.toStringAsFixed(0)} F',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
          const SizedBox(height: 10),
          Row(children: [
            Text('${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
            const Spacer(),
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
