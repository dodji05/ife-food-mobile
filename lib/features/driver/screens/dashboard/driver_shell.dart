import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/driver_provider.dart';

class DriverShell extends ConsumerWidget {
  final Widget child;
  const DriverShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverState = ref.watch(driverProvider);
    final loc = GoRouterState.of(context).matchedLocation;

    int idx = 0;
    if (loc == '/driver/missions') idx = 1;
    if (loc == '/driver/earnings') idx = 2;
    if (loc == '/driver/profile')  idx = 3;

    return Scaffold(
      body: child,
      floatingActionButton: driverState.missionCount > 0 && loc != '/driver/active-mission'
        ? FloatingActionButton.extended(
            onPressed: () => context.push('/driver/active-mission'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.delivery_dining_rounded),
            label: Text(
              '${driverState.missionCount} mission${driverState.missionCount > 1 ? 's' : ''} en cours',
              style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 14)),
          )
        : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(top: BorderSide(color: context.borderColor))),
        child: SafeArea(child: SizedBox(height: 60, child: Row(children: [
          _DNavItem(Icons.dashboard_rounded,              'Dashboard', idx == 0, () => context.go('/driver/dashboard')),
          _DNavItem(Icons.map_rounded,                    'Missions',  idx == 1, () => context.go('/driver/missions')),
          _DNavItem(Icons.account_balance_wallet_rounded, 'Gains',     idx == 2, () => context.go('/driver/earnings')),
          _DNavItem(Icons.person_rounded,                 'Profil',    idx == 3, () => context.go('/driver/profile')),
        ]))),
      ),
    );
  }
}

// Copie exacte du _NavItem client : pill animé + cardColor + icon 24
class _DNavItem extends StatelessWidget {
  final IconData icon; final String label; final bool sel; final VoidCallback onTap;
  const _DNavItem(this.icon, this.label, this.sel, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: sel ? AppColors.primary : const Color(0xFF9AA89C), size: 24)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
        color: sel ? AppColors.primary : const Color(0xFF9AA89C))),
    ])));
}
