// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Admin providers (validation pros + drivers)
//
// Endpoints backend (déjà existants, voir src/admin/admin.controller.ts) :
//   GET   /admin/pending/professionals
//   PATCH /admin/professionals/:id/validate   {status: 'VALIDATED'|'REJECTED', note?}
//   PATCH /admin/drivers/:id/validate         {status: ..., note?}
//
// Note : les endpoints admin sont gated par RolesGuard('ADMIN') côté backend
//        + le router mobile redirige tout non-admin vers son home — double safety.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

/// Liste des pros en attente de validation (PENDING).
/// Le backend retourne le record complet avec user joint (name, phone).
final pendingProfessionalsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/admin/pending/professionals');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().toList();
});

/// Idem pour les drivers PENDING.
final pendingDriversProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/admin/pending/drivers');
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().toList();
});

/// Notifier ultra-mince — pas d'état propre, juste des mutations admin.
class AdminNotifier {
  final Ref _ref;
  AdminNotifier(this._ref);

  /// Valide ou refuse un pro. `note` visible côté pro dans pro.adminNote.
  Future<void> validateProfessional(String proId,
      {required bool approve, String? note}) async {
    await ApiClient.instance.patch('/admin/professionals/$proId/validate', data: {
      'status': approve ? 'VALIDATED' : 'REJECTED',
      if (note != null && note.isNotEmpty) 'note': note,
    });
    _ref.invalidate(pendingProfessionalsProvider);
  }

  Future<void> validateDriver(String driverId,
      {required bool approve, String? note}) async {
    await ApiClient.instance.patch('/admin/drivers/$driverId/validate', data: {
      'status': approve ? 'VALIDATED' : 'REJECTED',
      if (note != null && note.isNotEmpty) 'note': note,
    });
    _ref.invalidate(pendingDriversProvider);
  }
}

final adminNotifierProvider = Provider<AdminNotifier>((ref) => AdminNotifier(ref));
