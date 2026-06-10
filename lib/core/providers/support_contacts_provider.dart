// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Contacts support configurés dans l'admin
// Endpoint public : GET /config/support-contacts
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

class SupportContact {
  final String id;
  final String type;   // 'email' | 'whatsapp' | 'phone'
  final String label;
  final String value;
  const SupportContact({
    required this.id,
    required this.type,
    required this.label,
    required this.value,
  });

  factory SupportContact.fromJson(Map<String, dynamic> j) => SupportContact(
    id:    j['id']    as String? ?? '',
    type:  j['type']  as String? ?? '',
    label: j['label'] as String? ?? '',
    value: j['value'] as String? ?? '',
  );

  /// Numéro sans '+' ni espaces pour wa.me (WhatsApp).
  String get cleanPhone => value.replaceAll(RegExp(r'[\s\+\-\(\)]'), '');
}

/// Retourne la liste des contacts support depuis la config admin.
/// Cache automatique Riverpod — 1 seul appel réseau par session.
final supportContactsProvider =
    FutureProvider.autoDispose<List<SupportContact>>((ref) async {
  final res  = await ApiClient.instance.get('/config/support-contacts');
  final raw  = res['data'] as Map<String, dynamic>? ?? {};
  final list = (raw['contacts'] as List<dynamic>?) ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(SupportContact.fromJson)
      .toList();
});
