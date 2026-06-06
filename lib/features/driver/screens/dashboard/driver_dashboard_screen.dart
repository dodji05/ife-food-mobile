// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD Driver — DriverDashboardScreen
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/widgets/notifications_list_widget.dart';
import '../../providers/driver_provider.dart';
import '../../widgets/available_mission_card.dart';

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth   = ref.watch(authProvider);
    final driver = ref.watch(driverProvider);
    final stats  = ref.watch(driverDashboardProvider);

    final user     = auth.user;
    final isOnline = driver.isOnline;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: CustomScrollView(slivers: [

        // ── App bar ───────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Container(
          color: AppColors.darkSurface,
          child: SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Bonjour, ${user?.firstName ?? 'Livreur'} 👋',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 22,
                      fontWeight: FontWeight.w900, color: context.textPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(
                    color: isOnline ? AppColors.primary : context.textMuted,
                    shape: BoxShape.circle,
                    boxShadow: isOnline ? [BoxShadow(
                      color: AppColors.primary.withOpacity(0.5),
                      blurRadius: 6, spreadRadius: 2)] : null,
                  )),
                  const SizedBox(width: 6),
                  Text(isOnline ? 'En ligne — Prêt pour les missions' : 'Hors ligne',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: isOnline ? AppColors.primary : context.textSecondary,
                      fontWeight: FontWeight.w600)),
                ]),
              ])),
              const NotifBellBadge(pushRoute: '/driver/notifications'),
            ]),
          )),
        )),

        // ── Toggle disponibilité ──────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: _AvailabilityToggle(
            isOnline: isOnline,
            loading: driver.isLoading,
            onToggle: () => ref.read(driverProvider.notifier).toggleAvailability(),
          ),
        )),

        // ── Missions disponibles ───────────────────────────────────────────────
        if (isOnline && driver.availableMissions.isNotEmpty) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.bolt_rounded, size: 18, color: AppColors.driverGreen),
              const SizedBox(width: 6),
              Text('Missions disponibles (${driver.availableMissions.length})',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w900, color: AppColors.driverGreen)),
            ]),
            const SizedBox(height: 12),
            ...driver.availableMissions.map((m) => AvailableMissionCard(mission: m)),
          ]),
        )),

        // ── Stats ─────────────────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: stats.when(
            loading: () => const _StatsShimmer(),
            error: (_, __) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.borderColor)),
              child: Row(children: [
                Icon(Icons.wifi_off_rounded, color: context.textSecondary, size: 20),
                const SizedBox(width: 10),
                Text('Statistiques indisponibles', style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
              ]),
            ),
            data: (data) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Hero card gains
              _EarningsCard(data: data),
              const SizedBox(height: 16),

              Text('Activité', style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Livraisons\naujourd\'hui',
                  value: '${data['todayDeliveries'] ?? 0}',
                  icon: Icons.delivery_dining_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: 'Note\nmoyenne',
                  value: '${((data['avgRating'] ?? 0) as num).toStringAsFixed(1)} ⭐',
                  icon: Icons.star_rounded, color: AppColors.accent)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _StatCard(
                  label: 'Ce mois',
                  value: '${data['monthDeliveries'] ?? 0} livr.',
                  icon: Icons.calendar_month_rounded, color: AppColors.info)),
                const SizedBox(width: 12),
                Expanded(child: _StatCard(
                  label: 'Total livraisons',
                  value: '${data['allDeliveries'] ?? 0}',
                  icon: Icons.check_circle_rounded, color: AppColors.success)),
              ]),
            ]),
          ),
        )),

        // ── Missions actives ──────────────────────────────────────────────────
        if (isOnline && driver.missionCount > 0) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: GestureDetector(
            onTap: () => context.push('/driver/active-mission'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary.withOpacity(0.15), context.cardColor],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4), width: 1.5),
              ),
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delivery_dining_rounded,
                    color: AppColors.primary, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${driver.missionCount} mission${driver.missionCount > 1 ? 's' : ''} active${driver.missionCount > 1 ? 's' : ''}',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                        fontWeight: FontWeight.w800, color: context.textPrimary)),
                  Text('Appuyez pour gérer vos livraisons',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: context.textSecondary)),
                ])),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.primary),
              ]),
            ),
          ),
        )),

        // ── Statut hors ligne ─────────────────────────────────────────────────
        if (!isOnline) SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vous êtes hors ligne', style: TextStyle(fontFamily: 'Nunito',
                  fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 6),
              Text('Passez en ligne pour commencer à recevoir des missions de livraison.',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    color: context.textSecondary, height: 1.5)),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.tips_and_updates_rounded, color: AppColors.accent, size: 16),
                const SizedBox(width: 8),
                const Expanded(child: Text(
                  'Conseils : Livrez aux heures de pointe (12h-14h, 19h-21h) pour maximiser vos gains !',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: AppColors.accent, height: 1.4))),
              ]),
            ]),
          ),
        )),

        // ── Actions rapides ───────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Actions rapides', style: TextStyle(fontFamily: 'Nunito',
                fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _QuickAction(
                emoji: '📋', label: 'Mes missions',
                onTap: () => context.go('/driver/missions'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(
                emoji: '💰', label: 'Mes gains',
                onTap: () => context.go('/driver/earnings'))),
              const SizedBox(width: 10),
              Expanded(child: _QuickAction(
                emoji: '👤', label: 'Profil',
                onTap: () => context.go('/driver/profile'))),
            ]),
          ]),
        )),
      ]),
    );
  }
}

// ── Hero card gains ───────────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _EarningsCard({required this.data});

  String _fmt(dynamic v) => '${((v ?? 0) as num).toStringAsFixed(0)} F';

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1A4D2E), Color(0xFF0D2B1A)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary.withOpacity(0.35)),
      boxShadow: [BoxShadow(
        color: AppColors.primary.withOpacity(0.15),
        blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_balance_wallet_rounded,
            color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        const Text('Mes gains', style: TextStyle(fontFamily: 'Nunito',
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary,
            letterSpacing: 0.3)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Text('Total : ${_fmt(data['totalEarnings'])}',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
                fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
      ]),
      const SizedBox(height: 16),
      IntrinsicHeight(child: Row(children: [
        Expanded(child: _EarningsPeriod(
          label: "Aujourd'hui",
          amount: _fmt(data['todayEarnings']),
          deliveries: data['todayDeliveries'] ?? 0,
          color: AppColors.primary,
          isFirst: true,
        )),
        VerticalDivider(color: AppColors.primary.withOpacity(0.2), width: 1),
        Expanded(child: _EarningsPeriod(
          label: 'Cette semaine',
          amount: _fmt(data['weekEarnings']),
          deliveries: data['weekDeliveries'] ?? 0,
          color: AppColors.success,
        )),
        VerticalDivider(color: AppColors.primary.withOpacity(0.2), width: 1),
        Expanded(child: _EarningsPeriod(
          label: 'Ce mois',
          amount: _fmt(data['monthEarnings']),
          deliveries: data['monthDeliveries'] ?? 0,
          color: AppColors.info,
        )),
      ])),
    ]),
  );
}

class _EarningsPeriod extends StatelessWidget {
  final String label, amount;
  final int deliveries;
  final Color color;
  final bool isFirst;
  const _EarningsPeriod({
    required this.label, required this.amount,
    required this.deliveries, required this.color, this.isFirst = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: isFirst ? 0 : 12, right: isFirst ? 12 : 0),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
          color: context.textSecondary, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(amount, style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text('$deliveries livr.', style: TextStyle(fontFamily: 'Nunito',
          fontSize: 11, color: context.textMuted)),
    ]),
  );
}

// ── Toggle disponibilité ──────────────────────────────────────────────────────
class _AvailabilityToggle extends StatelessWidget {
  final bool isOnline, loading;
  final VoidCallback onToggle;
  const _AvailabilityToggle(
      {required this.isOnline, required this.loading, required this.onToggle});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onToggle,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
            ? [AppColors.primary, AppColors.primary.withOpacity(0.7)]
            : [context.cardColor, AppColors.darkSurface],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline
            ? AppColors.primary.withOpacity(0.5)
            : context.borderColor,
          width: 1.5),
        boxShadow: isOnline
          ? [BoxShadow(color: AppColors.primary.withOpacity(0.3),
              blurRadius: 24, offset: const Offset(0, 8))]
          : [],
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isOnline ? 'EN LIGNE' : 'HORS LIGNE',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isOnline ? Colors.black : context.textMuted,
              letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Text(isOnline ? 'Vous recevez des missions' : 'Appuyez pour vous mettre en ligne',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700,
              color: isOnline ? Colors.black.withOpacity(0.8) : context.textSecondary)),
        ])),
        const SizedBox(width: 16),
        loading
          ? const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary))
          : AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 64, height: 34,
              decoration: BoxDecoration(
                color: isOnline ? Colors.black.withOpacity(0.25) : context.borderColor,
                borderRadius: BorderRadius.circular(17),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 28, height: 28, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.black : context.textSecondary,
                    shape: BoxShape.circle),
                  child: Icon(
                    isOnline ? Icons.power_settings_new_rounded : Icons.power_off_rounded,
                    color: isOnline ? AppColors.primary : context.bgColor, size: 16),
                ),
              ),
            ),
      ]),
    ),
  );
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value,
                   required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.cardColor, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.borderColor),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 10),
      Text(value, style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w900, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
          color: context.textSecondary, fontWeight: FontWeight.w600, height: 1.35)),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _QuickAction({required this.emoji, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.cardColor, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor)),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700,
            color: context.textSecondary)),
      ]),
    ),
  );
}

class _StatsShimmer extends StatelessWidget {
  const _StatsShimmer();
  @override
  Widget build(BuildContext context) => Column(children: [
    Container(height: 120, decoration: BoxDecoration(
        color: context.cardColor, borderRadius: BorderRadius.circular(20))),
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: Container(height: 90, decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(14)))),
      const SizedBox(width: 12),
      Expanded(child: Container(height: 90, decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(14)))),
    ]),
  ]);
}
