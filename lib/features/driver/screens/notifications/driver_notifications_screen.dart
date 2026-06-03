// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Notifications (vue driver)
// Thin wrapper sur NotificationsListWidget.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/notifications_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/widgets/notifications_list_widget.dart';

class DriverNotificationsScreen extends ConsumerWidget {
  const DriverNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final unread = ref.watch(unreadCountProvider);
    return Scaffold(
      backgroundColor: context.bgColor,
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
              label: Text(t.driverNotifMarkAllRead,
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
        ],
      ),
      body: NotificationsListWidget(
        // Côté driver : tap notif commande -> écran mission active
        // (le driver n'a pas de detail per-order séparé, juste la mission courante)
        onTapOrder: (_) => context.go('/driver/active-mission'),
      ),
    );
  }
}
