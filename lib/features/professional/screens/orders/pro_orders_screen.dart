import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';
import '../../../../shared/models/order.dart';

class ProOrdersScreen extends ConsumerStatefulWidget {
  const ProOrdersScreen({super.key});
  @override ConsumerState<ProOrdersScreen> createState() => _State();
}

class _State extends ConsumerState<ProOrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _tabLabels = ['Nouvelles', 'En cours', 'Livrées', 'Annulées'];
  final _tabStatuses = ['PAID', 'active', 'DELIVERED', 'CANCELLED'];

  @override
  void initState() { super.initState(); _tabs = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBg,
    appBar: AppBar(
      title: const Text('Commandes'),
      actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () { ref.invalidate(liveOrdersProvider); })],
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true, tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary, unselectedLabelColor: AppColors.darkSubtext,
        labelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w500, fontSize: 13),
        tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        indicatorWeight: 3,
      ),
    ),
    body: TabBarView(controller: _tabs, children: _tabStatuses.map((s) => _OrdersList(status: s)).toList()),
  );
}

class _OrdersList extends ConsumerWidget {
  final String status;
  const _OrdersList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(liveOrdersProvider(status));
    return RefreshIndicator(
      color: AppColors.primary, backgroundColor: AppColors.darkCard,
      onRefresh: () async => ref.invalidate(liveOrdersProvider(status)),
      child: orders.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString(), style: const TextStyle(color: AppColors.darkSubtext))),
        data: (list) => list.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📭', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text('Aucune commande ${_statusLabel(status).toLowerCase()}', style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) => _OrderCard(order: list[i], status: status),
            ),
      ),
    );
  }
  String _statusLabel(String s) { switch(s) { case 'PAID': return 'Nouvelles'; case 'active': return 'En cours'; case 'DELIVERED': return 'Livrées'; default: return 'Annulées'; } }
}

class _OrderCard extends ConsumerWidget {
  final ProOrder order; final String status;
  const _OrderCard({required this.order, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNew = status == 'PAID';
    return GestureDetector(
      onTap: () => context.push('/pro/order/${order.id}'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isNew ? AppColors.accent.withOpacity(0.08) : AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isNew ? AppColors.accent.withOpacity(0.5) : AppColors.darkBorder, width: isNew ? 2 : 1),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('#${order.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.darkSubtext))),
                _StatusBadge(order.status),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(order.clientName, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
                const Spacer(),
                Text('${order.totalAmount.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ]),
              const SizedBox(height: 6),
              Text('${order.items.length} article${order.items.length > 1 ? 's' : ''} • ${order.createdAt.hour}h${order.createdAt.minute.toString().padLeft(2,'0')}',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
              if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.note_rounded, size: 12, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Expanded(child: Text(order.specialInstructions!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.warning), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ],
            ]),
          ),
          // Quick action buttons for new orders
          if (isNew) Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
            child: Row(children: [
              Expanded(child: TextButton.icon(
                onPressed: () async {
                  await ref.read(proProvider.notifier).rejectOrder(order.id, 'Stock insuffisant');
                  ref.invalidate(liveOrdersProvider('PAID'));
                },
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.danger),
                label: const Text('Refuser', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger)),
              )),
              Container(width: 1, height: 40, color: AppColors.darkBorder),
              Expanded(child: TextButton.icon(
                onPressed: () async {
                  await ref.read(proProvider.notifier).acceptOrder(order.id);
                  ref.invalidate(liveOrdersProvider('PAID'));
                },
                icon: const Icon(Icons.check_rounded, size: 16, color: AppColors.success),
                label: const Text('Accepter', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
              )),
            ]),
          ) else if (order.status == 'ACCEPTED') Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
            child: TextButton.icon(
              onPressed: () async {
                await ref.read(proProvider.notifier).markInPreparation(order.id);
                ref.invalidate(liveOrdersProvider('active'));
              },
              icon: const Icon(Icons.restaurant_rounded, size: 16, color: AppColors.primary),
              label: const Text('Démarrer la préparation', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ) else if (order.status == 'IN_PREPARATION') Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.darkBorder))),
            child: TextButton.icon(
              onPressed: () async {
                await ref.read(proProvider.notifier).markReady(order.id);
                ref.invalidate(liveOrdersProvider('active'));
              },
              icon: const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
              label: const Text('Commande prête — Appeler le livreur', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.success)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'PAID'             => (AppColors.accent, 'Nouvelle'),
      'ACCEPTED'         => (AppColors.info, 'Acceptée'),
      'IN_PREPARATION'   => (AppColors.warning, 'En préparation'),
      'READY_FOR_PICKUP' => (AppColors.success, 'Prête !'),
      'DRIVER_ASSIGNED'  => (AppColors.primary, 'Livreur assigné'),
      'IN_DELIVERY'      => (AppColors.primary, 'En livraison'),
      'DELIVERED'        => (AppColors.success, 'Livrée'),
      'CANCELLED'        => (AppColors.danger, 'Annulée'),
      _                  => (AppColors.darkSubtext, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
