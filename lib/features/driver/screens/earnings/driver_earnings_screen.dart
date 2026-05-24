// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver Earnings Screen
//
// Affiche les gains du driver connecté :
//   - Hero card "Gains totaux" avec gradient + chips today/week
//   - Stats tiles (livraisons jour, note moyenne, total livraisons)
//   - Section virement (CTA passif, payouts auto hebdo)
//   - Historique transactions depuis GET /drivers/me/earnings
//
// Source : porté depuis ife-food-driver/features/earnings/screens/earnings_screen.dart
// Adapté à l'architecture multi-rôle (imports core/theme + providers locaux).
// Le screen référence utilisait des transactions hardcodées — ici on branche
// le vrai earningsProvider qui appelle /drivers/me/earnings.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/driver_provider.dart';

class DriverEarningsScreen extends ConsumerWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(driverDashboardProvider);
    final earnings = ref.watch(earningsProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Mes gains')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e.toString(), textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.darkSubtext, fontFamily: 'Nunito')),
        )),
        data: (data) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(driverDashboardProvider);
            ref.invalidate(earningsProvider);
            await ref.read(driverDashboardProvider.future);
          },
          child: ListView(padding: const EdgeInsets.all(16), children: [
            // Total earnings hero
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A4D2E), AppColors.darkCard],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Gains totaux',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('${(data['totalEarnings'] ?? 0).toStringAsFixed(0)} F CFA',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 36,
                    fontWeight: FontWeight.w900, color: AppColors.primary)),
                const SizedBox(height: 16),
                Row(children: [
                  _EarnChip("Aujourd'hui", '${(data['todayEarnings'] ?? 0).toStringAsFixed(0)} F'),
                  const SizedBox(width: 8),
                  _EarnChip('Cette semaine', '${(data['weekEarnings'] ?? 0).toStringAsFixed(0)} F'),
                  const SizedBox(width: 8),
                  _EarnChip('Ce mois', '${(data['monthEarnings'] ?? 0).toStringAsFixed(0)} F'),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Stats grid
            Row(children: [
              Expanded(child: _StatTile('📦', '${data['todayDeliveries'] ?? 0}', 'Livraisons\naujourd\'hui')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile('⭐', '${(data['avgRating'] ?? 0.0).toStringAsFixed(1)}', 'Note\nmoyenne')),
              const SizedBox(width: 10),
              Expanded(child: _StatTile('🏆', '${data['allDeliveries'] ?? 0}', 'Total\nlivraisons')),
            ]),
            const SizedBox(height: 24),

            // Payout section (passive — payouts gérés côté admin pour l'instant)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.darkCard, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Virement',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w800, color: AppColors.darkText)),
                const SizedBox(height: 4),
                const Text(
                  'Les virements sont effectués automatiquement chaque semaine '
                  'vers votre compte déclaré.',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    color: AppColors.darkSubtext, height: 1.4)),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  // TODO: brancher POST /drivers/me/payouts quand la feature
                  // côté backend sera prête. Pour l'instant snackbar info.
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Les virements sont automatisés — contactez le support si besoin'),
                      backgroundColor: AppColors.info,
                    ),
                  ),
                  icon: const Icon(Icons.account_balance_rounded, size: 18),
                  label: const Text('Demander un virement'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            const Text('Historique des gains',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                fontWeight: FontWeight.w800, color: AppColors.darkText)),
            const SizedBox(height: 12),

            // Transactions réelles depuis /drivers/me/earnings (vs sample
            // hardcodés référence). Types attendus : EARNING / TIP / BONUS.
            earnings.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
              ),
              error: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Impossible de charger les transactions',
                  style: TextStyle(fontFamily: 'Nunito', color: AppColors.darkSubtext)),
              ),
              data: (list) => list.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Aucune transaction pour l\'instant',
                      style: TextStyle(fontFamily: 'Nunito', color: AppColors.darkMuted))),
                  )
                : Column(children: list.map((tx) {
                    final type = tx['type']?.toString() ?? 'EARNING';
                    final amount = tx['amount'] ?? 0;
                    final createdAt = DateTime.tryParse(tx['createdAt'] ?? '') ?? DateTime.now();
                    final emoji = type == 'TIP' ? '🎁' : type == 'BONUS' ? '🎯' : '📦';
                    final label = type == 'TIP' ? 'Pourboire'
                                : type == 'BONUS' ? 'Bonus'
                                : 'Livraison';
                    return _Transaction(emoji, label,
                      '+ ${(amount as num).toStringAsFixed(0)} F',
                      '${createdAt.day.toString().padLeft(2,'0')}/${createdAt.month.toString().padLeft(2,'0')}/${createdAt.year}');
                  }).toList()),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _EarnChip extends StatelessWidget {
  final String label, value;
  const _EarnChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkSubtext)),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
        fontWeight: FontWeight.w800, color: AppColors.darkText)),
    ]),
  );
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: AppColors.darkCard, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.darkBorder)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 18,
        fontWeight: FontWeight.w900, color: AppColors.primary)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 10,
          color: AppColors.darkSubtext, height: 1.3)),
    ]),
  );
}

class _Transaction extends StatelessWidget {
  final String emoji, label, amount, date;
  const _Transaction(this.emoji, this.label, this.amount, this.date);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.darkCard, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.darkBorder)),
    child: Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
          fontWeight: FontWeight.w600, color: AppColors.darkText)),
        Text(date, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
          color: AppColors.darkMuted)),
      ])),
      Text(amount, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
        fontWeight: FontWeight.w800, color: AppColors.success)),
    ]),
  );
}
