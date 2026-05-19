import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';

class ClientMainShell extends ConsumerWidget {
  final Widget child;
  const ClientMainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    int idx = 0;
    if (loc == '/orders')  idx = 1;
    if (loc == '/profile') idx = 2;

    return Scaffold(
      // ─── DIAGNOSTIC TEMPORAIRE ──────────────────────────────────────────
      // Banner cyan dans le SHELL → visible quel que soit le child (Home,
      // Orders, Profile). Si l'utilisateur voit ce banner mais le Home reste
      // vide → bug spécifique au HomeScreen. S'il ne le voit pas → l'APK
      // installé ne contient pas ces changements (cache, mauvais artifact).
      body: Column(children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF00E5FF),
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 12),
          child: Text(
            '🔧 SHELL OK • route=$loc',
            style: const TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(child: child),
      ]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.lightBorder))),
        child: SafeArea(child: SizedBox(height: 60, child: Row(children: [
          _NavItem(Icons.home_rounded,         'Accueil',    idx == 0, () => context.go('/home')),
          _NavItem(Icons.receipt_long_rounded, 'Commandes',  idx == 1, () => context.go('/orders')),
          _NavItem(Icons.person_rounded,       'Profil',     idx == 2, () => context.go('/profile')),
        ]))),
      ),
    );
  }
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
