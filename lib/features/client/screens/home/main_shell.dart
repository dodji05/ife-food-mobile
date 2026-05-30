import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../providers/cart_provider.dart';

class ClientMainShell extends ConsumerWidget {
  final Widget child;
  const ClientMainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc       = GoRouterState.of(context).matchedLocation;
    final cartItems = ref.watch(cartProvider).totalItems;
    int idx = 0;
    if (loc == '/orders')  idx = 1;
    if (loc == '/profile') idx = 2;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(top: BorderSide(color: context.borderColor))),
        child: SafeArea(child: SizedBox(height: 60, child: Row(children: [
          _NavItem(Icons.home_rounded,         'Accueil',   idx == 0, () => context.go('/home')),
          _NavItem(Icons.receipt_long_rounded, 'Commandes', idx == 1, () => context.go('/orders')),
          _CartNavItem(cartItems),
          _NavItem(Icons.person_rounded,       'Profil',    idx == 2, () => context.go('/profile')),
        ]))),
      ),
    );
  }
}

// Icône panier dans la bottom nav — badge rouge si items présents.
class _CartNavItem extends StatelessWidget {
  final int count;
  const _CartNavItem(this.count);

  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(
    onTap: () => context.push('/cart'),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Stack(clipBehavior: Clip.none, children: [
        const Icon(Icons.shopping_bag_rounded, color: Color(0xFF9AA89C), size: 24),
        if (count > 0) Positioned(
          top: -4, right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8)),
            child: Text('$count',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 9,
                  fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ]),
      const SizedBox(height: 2),
      Text('Panier', style: TextStyle(fontFamily: 'Nunito', fontSize: 10,
        fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w500,
        color: count > 0 ? AppColors.primary : const Color(0xFF9AA89C))),
    ]),
  ));
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool sel; final VoidCallback onTap;
  const _NavItem(this.icon, this.label, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) => Expanded(child: InkWell(onTap: onTap, child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(duration: const Duration(milliseconds: 200),
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
