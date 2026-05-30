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
    if (loc == '/pro/orders')   idx = 1;
    if (loc == '/pro/catalogue')idx = 2;
    if (loc == '/pro/earnings') idx = 3;
    if (loc == '/pro/profile')  idx = 4;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(top: BorderSide(color: context.borderColor))),
        child: SafeArea(child: SizedBox(height: 60, child: Row(children: [
          _PNavItem(Icons.dashboard_rounded,      'Accueil',   idx == 0, () => context.go('/pro/dashboard'), badge: 0),
          _PNavItem(Icons.receipt_long_rounded,   'Commandes', idx == 1, () => context.go('/pro/orders'), badge: 3),
          _PNavItem(Icons.restaurant_menu_rounded,'Catalogue', idx == 2, () => context.go('/pro/catalogue'), badge: 0),
          _PNavItem(Icons.account_balance_wallet_rounded, 'Revenus', idx == 3, () => context.go('/pro/earnings'), badge: 0),
          _PNavItem(Icons.person_rounded,         'Profil',    idx == 4, () => context.go('/pro/profile'), badge: 0),
        ]))),
      ),
    );
  }
}

class _PNavItem extends StatelessWidget {
  final IconData icon; final String label; final bool sel;
  final VoidCallback onTap; final int badge;
  const _PNavItem(this.icon, this.label, this.sel, this.onTap, {required this.badge});
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Stack(
    alignment: Alignment.topCenter,
    children: [
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        AnimatedContainer(duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: sel ? AppColors.primary : context.textMuted, size: 22)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 9,
          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
          color: sel ? AppColors.primary : context.textMuted)),
      ]),
      if (badge > 0) Positioned(top: 4, right: 8, child: Container(
        width: 16, height: 16,
        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
        child: Center(child: Text('$badge', style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))))),
    ])));
}
