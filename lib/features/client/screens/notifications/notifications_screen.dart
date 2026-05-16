import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/notifications');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [TextButton(onPressed: () async {
          await ApiClient.instance.patch('/notifications/read-all');
          ref.invalidate(notificationsProvider);
        }, child: const Text('Tout lire'))],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (list) => list.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('🔔', style: TextStyle(fontSize: 56)),
              SizedBox(height: 12),
              Text('Aucune notification', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
            ]))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final n = list[i];
                final read = n['read'] == true;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: read ? Colors.white : AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: read ? AppColors.lightGrey.withOpacity(0.8) : AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                      child: Center(child: Text(_typeEmoji(n['type']), style: const TextStyle(fontSize: 18))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n['title'] ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: read ? FontWeight.w600 : FontWeight.w800, color: AppColors.nearBlack)),
                      const SizedBox(height: 2),
                      Text(n['body'] ?? '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey, height: 1.4)),
                    ])),
                    if (!read) Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  ]),
                );
              },
            ),
      ),
    );
  }

  String _typeEmoji(String? type) {
    switch (type) {
      case 'ORDER_NEW': return '🆕';
      case 'ORDER_ACCEPTED': return '✅';
      case 'ORDER_IN_PREPARATION': return '👨‍🍳';
      case 'ORDER_DRIVER_ASSIGNED': return '🛵';
      case 'ORDER_IN_DELIVERY': return '🚚';
      case 'ORDER_DELIVERED': return '🎉';
      case 'ORDER_CANCELLED': return '❌';
      case 'PAYOUT_SENT': return '💰';
      case 'ACCOUNT_VALIDATED': return '🎊';
      case 'PROMO': return '🏷️';
      default: return '🔔';
    }
  }
}
