// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Historique notifications (vue pro)
//
// Liste les notifs persistées en DB (table Notification, alimentée par chaque
// appel sendPush). Affiche :
//   • Cartes avec emoji icon, titre, body, date relative
//   • Distinction visuelle lu / non-lu (bandeau gauche + opacity)
//   • Tap : marque comme lu + deep link vers /pro/order/:id si data.orderId
//   • Bouton 'Tout marquer lu' dans l'AppBar (si non-lus)
//   • Empty state + Error state + pull-to-refresh
//
// Endpoints :
//   GET   /notifications
//   PATCH /notifications/:id/read
//   PATCH /notifications/read-all
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/notifications_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/app_notification.dart';

class ProNotificationsScreen extends ConsumerWidget {
  const ProNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton.icon(
              onPressed: () => _markAllRead(context, ref),
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
              label: const Text('Tout lu',
                style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (list) {
          if (list.isEmpty) return const _EmptyState();
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _NotificationTile(notif: list[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsNotifierProvider).markAllRead();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Toutes les notifications marquées lues'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }
}

// ── Tile une notif ──────────────────────────────────────────────────────────
class _NotificationTile extends ConsumerStatefulWidget {
  final AppNotification notif;
  const _NotificationTile({required this.notif});

  @override
  ConsumerState<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends ConsumerState<_NotificationTile> {
  bool _tapping = false;

  AppNotification get notif => widget.notif;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: notif.read ? 0.65 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: notif.read ? context.borderColor : AppColors.primary.withOpacity(0.4),
              width: notif.read ? 1 : 1.5,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Bandeau gauche bleu si non-lu (visuellement appuyé)
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: notif.read ? Colors.transparent : AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11), bottomLeft: Radius.circular(11),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Icône emoji
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(notif.iconEmoji, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            // Contenu : titre + body + date
            Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(
                    notif.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: notif.read ? FontWeight.w700 : FontWeight.w900,
                      color: context.textPrimary,
                    ),
                  )),
                  const SizedBox(width: 6),
                  Text(notif.relativeTime,
                    style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 11,
                      fontWeight: FontWeight.w600, color: context.textSecondary,
                    ),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(notif.body,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: context.textSecondary, height: 1.3)),
              ]),
            )),
            const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }

  /// Marque comme lu (best-effort) + navigation deep link.
  Future<void> _handleTap(BuildContext context) async {
    if (_tapping) return;
    setState(() => _tapping = true);

    if (!notif.read) {
      ref.read(notificationsNotifierProvider).markRead(notif.id).catchError((_) {});
    }

    if (!context.mounted) {
      setState(() => _tapping = false);
      return;
    }

    final orderId = notif.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      // /pro/order/:id est hors ShellRoute → push OK.
      context.push('/pro/order/$orderId');
    } else {
      // /pro/orders est dans le ShellRoute → go() pour remplacer la stack
      // au lieu d'empiler un 2e ShellRoute (évite la GlobalKey dupliquée).
      context.go('/pro/orders');
    }

    setState(() => _tapping = false);
  }
}

// ── States ──────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.notifications_none_rounded, size: 64, color: context.textMuted),
        const SizedBox(height: 16),
        Text('Aucune notification',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text(
          'Les nouvelles commandes et alertes apparaîtront ici.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary, height: 1.5),
        ),
      ]),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(message.replaceAll('Exception: ', ''),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ]),
    ),
  );
}
