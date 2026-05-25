// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Livraison planifiée : helper + dialog
//
// Usage :
//   final next = nextOpeningTime(pro.openingHours);
//   final ok   = await showScheduledDeliveryDialog(context, nextOpening: next);
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Calcule la prochaine plage d'ouverture à partir de maintenant.
/// Retourne `null` si les horaires sont absents ou si aucune ouverture
/// n'est trouvée dans les 7 prochains jours.
///
/// Structure attendue : `{"mon": {"open": "08:00", "close": "20:00"}, ...}`
/// Clés : `mon tue wed thu fri sat sun` (index = weekday - 1).
DateTime? nextOpeningTime(Map<String, dynamic>? openingHours) {
  if (openingHours == null || openingHours.isEmpty) return null;
  const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final now = DateTime.now();
  for (var offset = 0; offset < 8; offset++) {
    final candidate = now.add(Duration(days: offset));
    final dayKey = dayKeys[candidate.weekday - 1];
    final hours = openingHours[dayKey];
    if (hours is! Map) continue;
    final openStr = hours['open'] as String?;
    if (openStr == null) continue;
    final parts = openStr.split(':');
    if (parts.length < 2) continue;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) continue;
    final openDt = DateTime(candidate.year, candidate.month, candidate.day, h, m);
    if (openDt.isAfter(now)) return openDt;
  }
  return null;
}

String _formatNextOpening(DateTime dt) {
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dtDay = DateTime(dt.year, dt.month, dt.day);
  final diff  = dtDay.difference(today).inDays;
  final time  = '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
  if (diff == 0) return 'aujourd\'hui à $time';
  if (diff == 1) return 'demain à $time';
  const days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  final dayLabel = days[dt.weekday - 1];
  return '$dayLabel ${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à $time';
}

/// Affiche la boîte de dialogue "établissement fermé — planifier ?".
/// Retourne `true` si l'utilisateur confirme la livraison planifiée.
Future<bool> showScheduledDeliveryDialog(
  BuildContext context, {
  required DateTime? nextOpening,
}) async {
  final body = nextOpening != null
      ? 'Cet établissement est actuellement fermé. Il sera ouvert ${_formatNextOpening(nextOpening)}.\n\nVoulez-vous planifier votre livraison ?'
      : 'Cet établissement est actuellement fermé.\n\nVoulez-vous planifier votre livraison pour plus tard ?';

  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Établissement fermé',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900)),
      content: Text(body,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Planifier',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  return result == true;
}
