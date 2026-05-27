// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Widget liste de notifications (réutilisable cross-role)
//
// Utilisé par /pro/notifications, /notifications (client), /driver/notifications.
// Diffère pour chaque rôle SEULEMENT par la route de deep link au tap.
// Le caller passe une closure `onTapOrder(orderId)` qui décide où naviguer.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/theme/app_theme.dart';
import '../models/app_notification.dart';

class NotificationsListWidget extends ConsumerWidget {
  /// Callback appelé au tap sur une notif qui référence un orderId.
  /// La logique de routing est déléguée au caller (rôle-aware).
  final void Function(String orderId)? onTapOrder;

  const NotificationsListWidget({super.key, this.onTapOrder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsProvider);

    return async.when(
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
            itemBuilder: (_, i) => _Tile(notif: list[i], onTapOrder: onTapOrder),
          ),
        );
      },
    );
  }
}

class _Tile extends ConsumerStatefulWidget {
  final AppNotification notif;
  final void Function(String)? onTapOrder;
  const _Tile({required this.notif, this.onTapOrder});

  @override
  ConsumerState<_Tile> createState() => _TileState();
}

class _TileState extends ConsumerState<_Tile> {
  bool _tapping = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      if (_tapping) return;
      setState(() => _tapping = true);
      if (!widget.notif.read) {
        ref.read(notificationsNotifierProvider).markRead(widget.notif.id).catchError((_) {});
      }
      final orderId = widget.notif.orderId;
      if (orderId != null && orderId.isNotEmpty && context.mounted) {
        widget.onTapOrder?.call(orderId);
      }
      if (mounted) setState(() => _tapping = false);
    },
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: widget.notif.read ? 0.65 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.notif.read ? AppColors.darkBorder : AppColors.primary.withOpacity(0.4),
            width: widget.notif.read ? 1 : 1.5,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 4, height: 64,
            decoration: BoxDecoration(
              color: widget.notif.read ? Colors.transparent : AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11), bottomLeft: Radius.circular(11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(widget.notif.iconEmoji, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(
                  widget.notif.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: widget.notif.read ? FontWeight.w700 : FontWeight.w900,
                    color: AppColors.darkText,
                  ),
                )),
                const SizedBox(width: 6),
                Text(widget.notif.relativeTime,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                      fontWeight: FontWeight.w600, color: AppColors.darkSubtext)),
              ]),
              const SizedBox(height: 2),
              Text(widget.notif.body,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    color: AppColors.darkSubtext, height: 1.3)),
            ]),
          )),
          const SizedBox(width: 8),
        ]),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.darkMuted),
        SizedBox(height: 16),
        Text('Aucune notification',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkText)),
        SizedBox(height: 6),
        Text('Les nouvelles commandes et alertes apparaîtront ici.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, height: 1.5)),
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
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
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

// ── Bell badge réutilisable (header dashboards) ────────────────────────────
class NotifBellBadge extends ConsumerWidget {
  /// Route vers laquelle pousser au tap (ex: '/notifications', '/driver/notifications').
  final String pushRoute;
  const NotifBellBadge({super.key, required this.pushRoute});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(pushRoute),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: unread > 0 ? AppColors.accent : AppColors.darkSubtext,
              size: 26,
            ),
          ),
        ),
      ),
      if (unread > 0) Positioned(
        right: 2, top: 2,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
          decoration: BoxDecoration(
            color: AppColors.danger,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.darkSurface, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Text(unread > 99 ? '99+' : '$unread',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ),
    ]);
  }
}
