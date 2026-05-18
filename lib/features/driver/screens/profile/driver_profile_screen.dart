// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver / Profil
//
// Stub remplacé par : avatar éditable + infos user + actions (PIN, notif,
// déconnexion). Mêmes patterns que ClientProfileScreen pour cohérence cross-role.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/route_params.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/editable_avatar.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── User card (header gradient) ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF0E7A4D)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            EditableAvatar(
              currentUrl: user?.avatarUrl,
              fallbackText: user?.displayName ?? '?',
              radius: 30,
              backgroundColor: Colors.white.withOpacity(0.25),
              textColor: Colors.white,
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.displayName ?? 'Livreur',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text(user?.phone ?? '',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.85))),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.two_wheeler_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text('Livreur ifè',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: Colors.white.withOpacity(0.85))),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        _Section('Compte', [
          _Item(Icons.lock_rounded, 'Modifier le PIN', () {
            final phone = user?.phone;
            if (phone == null || phone.isEmpty) return;
            context.push('/auth/pin', extra: PinRouteParams(mode: 'set', phone: phone));
          }),
          _Item(Icons.notifications_rounded, 'Mes notifications',
              () => context.push('/driver/notifications')),
          _Item(Icons.language_rounded, 'Langue', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Bientôt disponible'),
              backgroundColor: AppColors.darkSubtext,
            ));
          }),
        ]),
        const SizedBox(height: 12),

        _Section('Aide & Légal', [
          _Item(Icons.support_agent_rounded, 'Contacter le support', () {}),
          _Item(Icons.description_rounded, 'Charte du livreur', () {}),
          _Item(Icons.privacy_tip_rounded, 'Politique de confidentialité', () {}),
        ]),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Se déconnecter',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/onboarding');
            },
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section(this.title, this.items);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title.toUpperCase(),
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800,
            color: AppColors.darkSubtext, letterSpacing: 0.5)),
    ),
    Container(
      decoration: BoxDecoration(color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Column(children: items.asMap().entries.map((e) => Column(children: [
        if (e.key > 0) const Divider(height: 1, color: AppColors.darkBorder, indent: 54),
        e.value,
      ])).toList()),
    ),
  ]);
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String  label;
  final VoidCallback onTap;
  const _Item(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 18),
    ),
    title: Text(label,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.darkMuted, size: 18),
    onTap: onTap,
  );
}
