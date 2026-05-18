import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/route_params.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../../providers/pro_provider.dart';

class ProProfileScreen extends ConsumerWidget {
  const ProProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final proState = ref.watch(proProvider);
    final pro = proState.professional;
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Mon Profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Establishment card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0A2030), AppColors.darkCard], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: Center(child: Text(pro?.categoryEmoji ?? '🏪', style: const TextStyle(fontSize: 28)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pro?.businessName ?? 'Mon établissement', style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.darkText)),
                const SizedBox(height: 2),
                Text(user?.displayName ?? '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
              ])),
              // Status badge
              if (pro != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: pro.isValidated ? AppColors.success.withOpacity(0.12) : AppColors.warning.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(pro.statusLabel, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700,
                  color: pro.isValidated ? AppColors.success : AppColors.warning)),
              ),
            ]),
            if (pro != null) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.darkBorder),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(pro.address ?? '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(pro.phone ?? user?.phone ?? '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext)),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Pending warning
        if (pro?.isPending == true) Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
          child: const Row(children: [
            Text('⏳', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(child: Text('Votre compte est en cours de validation. Vous serez notifié dès l\'activation.', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.warning, height: 1.4))),
          ]),
        ),

        _Section('Établissement', [
          _Item(Icons.store_rounded, 'Modifier mes informations',
              () => context.push('/pro/edit-info')),
          // Zone de livraison = même écran (deliveryRadiusKm) → on évite
          // un écran dédié, l'utilisateur trouve dans 'Modifier mes infos'.
          _Item(Icons.schedule_rounded, 'Horaires d\'ouverture',
              () => context.push('/pro/schedule')),
        ]),
        const SizedBox(height: 12),

        _Section('Compte', [
          _Item(Icons.lock_rounded, 'Modifier le PIN', () {
            final phone = user?.phone;
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Téléphone manquant — reconnectez-vous.'),
                backgroundColor: AppColors.danger,
              ));
              return;
            }
            // mode='set' force la double saisie (création + confirm).
            // Le redirect GoRouter respecte ce mode (cf. app_router.dart:143).
            context.push('/auth/pin',
                extra: PinRouteParams(mode: 'set', phone: phone));
          }),
          _Item(Icons.language_rounded, 'Langue',
              () => showLanguagePicker(context, ref,
                  currentLang: user?.lang ?? 'fr', darkTheme: true)),
          _Item(Icons.badge_rounded, 'Mes documents', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Gestion documents — bientôt disponible'),
              backgroundColor: AppColors.darkSubtext,
            ));
          }),
        ]),
        const SizedBox(height: 12),

        _Section('Aide & Légal', [
          _Item(Icons.support_agent_rounded, 'Contacter le support', () {}),
          _Item(Icons.description_rounded, 'Charte du professionnel', () {}),
          _Item(Icons.privacy_tip_rounded, 'Politique de confidentialité', () {}),
        ]),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Se déconnecter', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
            onTap: () async { await ref.read(authProvider.notifier).logout(); if (context.mounted) context.go('/onboarding'); },
          ),
        ),
        const SizedBox(height: 40),
        const Center(child: Text('ifè PRO v1.0.0 • Ets SWK FAKEYE', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkMuted))),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// Language picker extrait dans lib/shared/widgets/language_picker.dart
// (réutilisable cross-role : client + driver + pro).

class _Section extends StatelessWidget {
  final String title; final List<_Item> items;
  const _Section(this.title, this.items);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(title, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkSubtext, letterSpacing: 0.5))),
    Container(decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
      child: Column(children: items.asMap().entries.map((e) => Column(children: [if (e.key > 0) const Divider(height: 1, color: AppColors.darkBorder, indent: 54), e.value])).toList())),
  ]);
}

class _Item extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _Item(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 18)),
    title: Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkText)),
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.darkMuted, size: 18),
    onTap: onTap,
  );
}
