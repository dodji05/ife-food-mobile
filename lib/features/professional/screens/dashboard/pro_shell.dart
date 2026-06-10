import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

class ProShell extends ConsumerWidget {
  final Widget child;
  const ProShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    if (loc == '/pro/orders')    idx = 1;
    if (loc == '/pro/catalogue') idx = 2;
    if (loc == '/pro/earnings')  idx = 3;
    if (loc == '/pro/profile')   idx = 4;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(top: BorderSide(color: context.borderColor))),
        child: SafeArea(child: SizedBox(height: 60, child: Row(children: [
          _PNavItem(Icons.dashboard_rounded,               'Accueil',   idx == 0, () => context.go('/pro/dashboard')),
          _PNavItem(Icons.receipt_long_rounded,            'Commandes', idx == 1, () => context.go('/pro/orders')),
          _PNavItem(Icons.restaurant_menu_rounded,         'Catalogue', idx == 2, () => context.go('/pro/catalogue')),
          _PNavItem(Icons.account_balance_wallet_rounded,  'Revenus',   idx == 3, () => context.go('/pro/earnings')),
          _PNavItem(Icons.person_rounded,                  'Profil',    idx == 4, () => context.go('/pro/profile')),
        ]))),
      ),
    );
  }
}

// Copie exacte du _NavItem client : pill animé + cardColor + icon 24
class _PNavItem extends StatelessWidget {
  final IconData icon; final String label; final bool sel; final VoidCallback onTap;
  const _PNavItem(this.icon, this.label, this.sel, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
