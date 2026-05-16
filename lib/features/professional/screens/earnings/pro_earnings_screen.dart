import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';

class ProEarningsScreen extends ConsumerWidget {
  const ProEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Revenus')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) => ListView(padding: const EdgeInsets.all(16), children: [
          // Revenue hero
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF0A2A14), AppColors.darkCard], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Revenus du mois', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('${(data['revenue']?['month'] ?? 0).toStringAsFixed(0)} F CFA',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.primary)),
              const SizedBox(height: 16),
              Row(children: [
                _EChip("Aujourd'hui", '${(data['revenue']?['today'] ?? 0).toStringAsFixed(0)} F'),
                const SizedBox(width: 10),
                _EChip('Cette semaine', '${(data['revenue']?['week'] ?? 0).toStringAsFixed(0)} F'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Stats
          Row(children: [
            _StatTile('📦', '${data['orders']?['today'] ?? 0}', 'Commandes\naujourd\'hui'),
            const SizedBox(width: 10),
            _StatTile('💰', '15%', 'Commission\nplateforme'),
            const SizedBox(width: 10),
            _StatTile('⭐', '4.8', 'Note\nmoyenne'),
          ]),
          const SizedBox(height: 20),

          // Commission note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.info.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.info.withOpacity(0.3))),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_rounded, color: AppColors.info, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('La commission de la plateforme (15%) est déduite de votre sous-total. La TVA ne s\'applique pas aux commissions ifè FOOD.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.info, height: 1.4))),
            ]),
          ),
          const SizedBox(height: 20),

          // Payout section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Virement', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 4),
              const Text('Les virements sont effectués automatiquement chaque semaine. Vous pouvez également demander un virement manuel à tout moment.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, height: 1.4)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download_rounded, size: 16),
                  label: const Text('Relevé', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, side: const BorderSide(color: AppColors.primary), minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.account_balance_rounded, size: 16),
                  label: const Text('Virement', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _EChip extends StatelessWidget {
  final String label, value;
  const _EChip(this.label, this.value);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkSubtext)),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)),
    ]),
  );
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  const _StatTile(this.emoji, this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 22)),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary)),
      const SizedBox(height: 2),
      Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, color: AppColors.darkSubtext, height: 1.3)),
    ]),
  ));
}
