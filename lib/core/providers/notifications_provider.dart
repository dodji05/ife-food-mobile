// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Notifications provider (cross-role, partagé par client/driver/pro)
//
// - notificationsProvider     : FutureProvider liste des notifs du user
// - unreadCountProvider       : Provider dérivé qui compte les non-lues
//                               (pour badges dans les barres de nav)
// - NotificationsNotifier     : actions markRead + markAllRead
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../../shared/models/app_notification.dart';

/// Liste des notifications du user authentifié, triées par date desc (renvoyé
/// par le backend qui fait orderBy createdAt desc + take 50).
final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final res = await ApiClient.instance.get('/notifications');
  final list = res['data'] as List? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(AppNotification.fromJson)
      .toList();
});

/// Nombre de notifs non-lues — dérivé du provider liste. Utilisable comme
/// badge dans les onglets nav. Retourne 0 si la liste n'a pas encore chargé.
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationsProvider).maybeWhen(
    data: (list) => list.where((n) => !n.read).length,
    orElse: () => 0,
  );
});

/// Actions sur les notifs (mark read / mark all read).
/// Le provider n'a pas d'état propre — il expose juste les mutations.
class NotificationsNotifier {
  final Ref _ref;
  NotificationsNotifier(this._ref);

  Future<void> markRead(String notificationId) async {
    await ApiClient.instance.patch('/notifications/$notificationId/read');
    _ref.invalidate(notificationsProvider);
  }

  Future<void> markAllRead() async {
    await ApiClient.instance.patch('/notifications/read-all');
    _ref.invalidate(notificationsProvider);
  }
}

final notificationsNotifierProvider = Provider<NotificationsNotifier>((ref) {
  return NotificationsNotifier(ref);
});
