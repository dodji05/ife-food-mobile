// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver Mission History Screen
//
// Liste les livraisons passées du driver (DELIVERED ou FAILED).
// Source backend : GET /deliveries/driver/history
// Source UI : porté depuis ife-food-driver/features/missions/screens/mission_history_screen.dart
//
// Format de réponse attendu :
//   { data: [{ id, status, distanceKm, createdAt,
//              order: { deliveryFee, professional: { businessName, ... } } }] }
//
// L'enum backend DeliveryStatus n'a pas de CANCELLED — on utilise FAILED pour
// matérialiser les missions annulées (cf deliveries.service.getDriverHistory).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';

final missionHistoryProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/deliveries/driver/history');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

class MissionHistoryScreen extends ConsumerWidget {
  const MissionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(missionHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Mes missions')),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(missionHistoryProvider);
          await ref.read(missionHistoryProvider.future);
        },
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => _Empty(
            title: 'Erreur de chargement',
            subtitle: 'Vérifiez votre connexion puis réessayez.',
          ),
          data: (list) => list.isEmpty
            ? _Empty(
                title: 'Aucune mission',
                subtitle: 'Passez en ligne et acceptez votre\npremière mission !',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) => _MissionCard(m: list[i]),
              ),
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final Map<String, dynamic> m;
  const _MissionCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final isDelivered = m['status'] == 'DELIVERED';
    final date = DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now();
    final order = m['order'] as Map<String, dynamic>?;
    final pro = order?['professional'] as Map<String, dynamic>?;
    final businessName = pro?['businessName'] ?? 'Livraison';
    final deliveryFee = order?['deliveryFee'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isDelivered
                ? AppColors.primary.withOpacity(0.12)
                : AppColors.danger.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isDelivered ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isDelivered ? AppColors.primary : AppColors.danger,
            size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(businessName,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w700, color: AppColors.darkText)),
          const SizedBox(height: 2),
          Text(
            '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'
            ' à ${date.hour.toString().padLeft(2,'0')}h${date.minute.toString().padLeft(2,'0')}',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
              color: AppColors.darkSubtext)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            isDelivered && deliveryFee != null
              ? '+ ${(deliveryFee as num).toStringAsFixed(0)} F'
              : isDelivered ? '+ —' : 'Annulé',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isDelivered ? AppColors.success : AppColors.danger)),
          if (m['distanceKm'] != null)
            Text('${(m['distanceKm'] as num).toStringAsFixed(1)} km',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                color: AppColors.darkMuted)),
        ]),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  final String title, subtitle;
  const _Empty({required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      const SizedBox(height: 140),
      const Center(child: Text('📭', style: TextStyle(fontSize: 52))),
      const SizedBox(height: 12),
      Center(child: Text(title,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 18,
          fontWeight: FontWeight.w800, color: AppColors.darkText))),
      const SizedBox(height: 8),
      Center(child: Text(subtitle, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
          color: AppColors.darkSubtext))),
    ],
  );
}
