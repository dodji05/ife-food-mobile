import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../providers/pro_provider.dart';

class ProDashboardScreen extends ConsumerWidget {
  const ProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth      = ref.watch(authProvider);
    final proState  = ref.watch(proProvider);
    final stats     = ref.watch(dashboardProvider);
    final newOrders = ref.watch(liveOrdersProvider('PAID'));

    final user = auth.user;
    final pro  = proState.professional;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: CustomScrollView(slivers: [

        // ── En-tête ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Container(
          color: AppColors.darkSurface,
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bonjour 👋', style: const TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
                const SizedBox(height: 2),
                Text(pro?.businessName ?? user?.displayName ?? 'Mon établissement',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 20,
                      fontWeight: FontWeight.w900, color: AppColors.darkText)),
              ])),
              // Badge statut ouvert / fermé
              GestureDetector(
                onTap: () {}, // TODO: toggle open/close
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (pro?.isOpen ?? false)
                        ? AppColors.success.withOpacity(0.15)
                        : AppColors.darkCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (pro?.isOpen ?? false)
                          ? AppColors.success.withOpacity(0.4)
                          : AppColors.darkBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(
                      color: (pro?.isOpen ?? false) ? AppColors.success : AppColors.darkMuted,
                      shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text((pro?.isOpen ?? false) ? 'Ouvert' : 'Fermé',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: (pro?.isOpen ?? false) ? AppColors.success : AppColors.darkSubtext)),
                  ]),
                ),
              ),
            ]),
          )),
        )),

        // ── Nouvelle commande en attente ────────────────────────────────────
        newOrders.when(
          loading: () => const SliverToBoxAdapter(),
          error: (_, __) => const SliverToBoxAdapter(),
          data: (list) => list.isEmpty ? const SliverToBoxAdapter() : SliverToBoxAdapter(
            child: GestureDetector(
              onTap: () => context.go('/pro/orders'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
                ),
                child: Row(children: [
                  const Text('🔔', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${list.length} nouvelle${list.length > 1 ? 's' : ''} commande${list.length > 1 ? 's' : ''}',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          fontWeight: FontWeight.w800, color: AppColors.accent)),
                    const Text('Appuyez pour accepter ou refuser',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          color: AppColors.darkSubtext)),
                  ])),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.accent),
                ]),
              ),
            ),
          ),
        ),

        // ── Statistiques du jour ─────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: stats.when(
            loading: () => const _StatsShimmer(),
            error: (_, __) => const _StatsPlaceholder(),
            data: (data) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Aujourd'hui", style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Commandes',
                  value: '${data['todayOrders'] ?? data['ordersToday'] ?? 0}',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: 'Revenus du jour',
                  value: '${((data['todayRevenue'] ?? data['revenueToday'] ?? 0) as num).toStringAsFixed(0)} F',
                  icon: Icons.account_balance_wallet_rounded,
                  color: AppColors.success)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Note moyenne',
                  value: '${((data['avgRating'] ?? 0) as num).toStringAsFixed(1)} ⭐',
                  icon: Icons.star_rounded,
                  color: AppColors.accent)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: 'Commandes totales',
                  value: '${data['totalOrders'] ?? 0}',
                  icon: Icons.bar_chart_rounded,
                  color: AppColors.info)),
              ]),
            ]),
          ),
        )),

        // ── Actions rapides ──────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: const Text('Actions rapides', style: TextStyle(fontFamily: 'Nunito',
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkText)),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid.count(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _QuickAction('📋', 'Commandes', () => context.go('/pro/orders')),
              _QuickAction('🍽️', 'Catalogue',  () => context.go('/pro/catalogue')),
              _QuickAction('💰', 'Revenus',    () => context.go('/pro/earnings')),
              _QuickAction('⏰', 'Horaires',   () => context.push('/pro/schedule')),
              _QuickAction('⭐', 'Avis',       () => context.push('/pro/reviews')),
              _QuickAction('👤', 'Profil',     () => context.go('/pro/profile')),
            ],
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
                   required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
          color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _QuickAction(this.emoji, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
            fontWeight: FontWeight.w700, color: AppColors.darkSubtext)),
      ]),
    ),
  );
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const _ShimmerBox(width: 100, height: 18),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: Container(height: 90, decoration: BoxDecoration(
          color: AppColors.darkCard, borderRadius: BorderRadius.circular(14)))),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 90, decoration: BoxDecoration(
          color: AppColors.darkCard, borderRadius: BorderRadius.circular(14)))),
    ]),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: Container(height: 90, decoration: BoxDecoration(
          color: AppColors.darkCard, borderRadius: BorderRadius.circular(14)))),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 90, decoration: BoxDecoration(
          color: AppColors.darkCard, borderRadius: BorderRadius.circular(14)))),
    ]),
  ]);
}

class _ShimmerBox extends StatelessWidget {
  final double width, height;
  const _ShimmerBox({required this.width, required this.height});
  @override
  Widget build(BuildContext context) => Container(
    width: width, height: height,
    decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(8)));
}

class _StatsPlaceholder extends StatelessWidget {
  const _StatsPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
    child: const Row(children: [
      Icon(Icons.wifi_off_rounded, color: AppColors.darkSubtext, size: 20),
      SizedBox(width: 10),
      Text('Statistiques indisponibles', style: TextStyle(
          fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
    ]),
  );
}
