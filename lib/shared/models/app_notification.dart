// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle AppNotification
// Correspond à la réponse de GET /notifications.
//
// Le backend persiste TOUTES les notifs envoyées (push FCM + alertes système)
// dans la table `Notification`. Le mobile lit cette liste pour afficher
// l'historique + badge non-lus + actions (marquer lu / tout marquer).
// ─────────────────────────────────────────────────────────────────────────────

class AppNotification {
  final String  id;
  final String  userId;
  /// Type métier : `SYSTEM`, `ORDER_PAID`, `ORDER_DELIVERED`, etc.
  /// Le backend pour l'instant met `SYSTEM` pour tout, mais le champ est
  /// déjà typé en DB pour catégoriser plus finement plus tard.
  final String  type;
  final String  title;
  final String  body;
  final bool    read;
  /// Données associées (orderId, status, …). Utilisé pour le deep link au tap.
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    this.data,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id:        j['id']      as String? ?? '',
    userId:    j['userId']  as String? ?? '',
    type:      j['type']    as String? ?? 'SYSTEM',
    title:     j['title']   as String? ?? '',
    body:      j['body']    as String? ?? '',
    read:      j['read']    as bool?   ?? false,
    data:      j['data'] is Map ? Map<String, dynamic>.from(j['data'] as Map) : null,
    createdAt: (DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now()).toLocal(),
  );

  // ── Helpers d'affichage ──────────────────────────────────────────────────
  /// Icône appropriée selon le type — fallback sur cloche générique.
  String get iconEmoji => switch (type) {
    'ORDER_PAID' || 'PAID'        => '🔔',
    'ORDER_ACCEPTED'              => '✅',
    'ORDER_IN_PREPARATION'        => '🍳',
    'ORDER_READY_FOR_PICKUP'      => '📦',
    'ORDER_IN_DELIVERY'           => '🛵',
    'ORDER_DELIVERED' || 'DELIVERED' => '🎉',
    'ORDER_CANCELLED' || 'CANCELLED' => '❌',
    'PROMO'                       => '🎁',
    _                             => '🔔',
  };

  /// Format relatif court : "à l'instant", "5min", "2h", "3j", sinon date courte.
  String get relativeTime {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60)   return 'à l\'instant';
    if (diff.inMinutes < 60)   return '${diff.inMinutes}min';
    if (diff.inHours   < 24)   return '${diff.inHours}h';
    if (diff.inDays    < 7)    return '${diff.inDays}j';
    return '${createdAt.day.toString().padLeft(2, '0')}/'
           '${createdAt.month.toString().padLeft(2, '0')}';
  }

  /// Order id parsé depuis `data` — utilisé pour le deep link au tap.
  String? get orderId => data?['orderId']?.toString();

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id, userId: userId, type: type, title: title, body: body,
    read: read ?? this.read, data: data, createdAt: createdAt,
  );
}
