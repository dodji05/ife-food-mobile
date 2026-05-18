import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/route_params.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/editable_avatar.dart';
import '../../../../shared/widgets/language_picker.dart';

class ClientProfileScreen extends ConsumerWidget {
  const ClientProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Mon Profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // User card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF2E8B57)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
              Text(user?.displayName ?? 'Utilisateur', style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text(user?.phone ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8))),
            ])),
            IconButton(onPressed: () {}, icon: const Icon(Icons.edit_rounded, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 20),

        _MenuSection(title: 'Compte', items: [
          _MenuItem(icon: Icons.location_on_rounded, label: 'Mes adresses', onTap: () => context.push('/addresses')),
          _MenuItem(icon: Icons.lock_rounded, label: 'Modifier mon PIN', onTap: () => context.push('/auth/pin', extra: const PinRouteParams(mode: 'set'))),
          _MenuItem(
            icon: Icons.language_rounded,
            label: 'Langue',
            sub: languageLabel(user?.lang ?? 'fr'),
            onTap: () => showLanguagePicker(context, ref,
                currentLang: user?.lang ?? 'fr', darkTheme: false),
          ),
          _MenuItem(
            icon: Icons.currency_exchange_rounded,
            label: 'Pays / Devise',
            sub: '${user?.countryCode ?? 'BJ'} • ${user?.currency ?? 'XOF'}',
            onTap: () {}, // wired dans le commit suivant (country_picker)
          ),
        ]),
        const SizedBox(height: 12),

        _MenuSection(title: 'Aide & Légal', items: [
          _MenuItem(icon: Icons.support_agent_rounded, label: 'Contacter le support', onTap: () {}),
          _MenuItem(icon: Icons.description_rounded, label: "Conditions d'utilisation", onTap: () => context.push('/legal/CGU')),
          _MenuItem(icon: Icons.privacy_tip_rounded, label: 'Politique de confidentialité', onTap: () => context.push('/legal/PRIVACY')),
          _MenuItem(icon: Icons.info_rounded, label: 'À propos', onTap: () => context.push('/legal/ABOUT')),
        ]),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('Se déconnecter', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.error)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/onboarding');
            },
          ),
        ),
        const SizedBox(height: 40),
        const Center(child: Text('ifè FOOD v1.0.0 • Ets SWK FAKEYE', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.grey))),
        const SizedBox(height: 20),
      ]),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title; final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.grey, letterSpacing: 0.5))),
    Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
      child: Column(children: items.asMap().entries.map((e) => Column(children: [
        if (e.key > 0) const Divider(height: 1, indent: 54),
        e.value,
      ])).toList()),
    ),
  ]);
}

class _MenuItem extends StatelessWidget {
  final IconData icon; final String label; final String? sub; final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 18)),
    title: Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.nearBlack)),
    subtitle: sub != null ? Text(sub!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)) : null,
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.lightGrey, size: 20),
    onTap: onTap,
  );
}
