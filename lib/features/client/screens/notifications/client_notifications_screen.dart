// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Notifications (vue client)
// Thin wrapper sur NotificationsListWidget + deep link role-aware.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/notifications_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/notifications_list_widget.dart';

class ClientNotificationsScreen extends ConsumerWidget {
  const ClientNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: () async {
                try {
                  await ref.read(notificationsNotifierProvider).markAllRead();
                } catch (_) {}
              },
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
              label: const Text('Tout lu',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
        ],
      ),
      body: NotificationsListWidget(
        // Côté client : la notif référence sa propre commande -> /order/:id
        onTapOrder: (orderId) => context.push('/order/$orderId'),
      ),
    );
  }
}
