import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/order.dart';

final ordersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final res = await ApiClient.instance.get('/orders/my-orders');
  final list = res['data'] as List? ?? [];
  return list.map((e) => Order.fromJson(e)).toList();
});

class OrderHistoryScreen extends ConsumerWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(ordersProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Mes commandes')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) => list.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('📦', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              const Text('Aucune commande', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
              const SizedBox(height: 8),
              const Text('Vos commandes apparaîtront ici', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: () => context.go('/home'), icon: const Icon(Icons.explore_rounded), label: const Text('Commander'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(180, 48))),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _OrderCard(order: list[i]),
            ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  Color get _statusColor {
    if (order.isDelivered) return AppColors.success;
    if (order.isCancelled) return AppColors.error;
    if (order.isActive) return AppColors.primary;
    return AppColors.grey;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/order/${order.id}'),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.professional?['businessName'] ?? 'Restaurant',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.nearBlack))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(order.statusLabel, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: _statusColor)),
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
            onPressed: () => context.push('/order/${order.id}'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 12), side: const BorderSide(color: AppColors.primary)),
            child: const Text('Recommander', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
          ),
          if (order.isActive) ElevatedButton(
            onPressed: () => context.push('/tracking/${order.id}'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 32), padding: const EdgeInsets.symmetric(horizontal: 12)),
            child: const Text('Suivre', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
          ),
        ]),
      ]),
    ),
  );
}
