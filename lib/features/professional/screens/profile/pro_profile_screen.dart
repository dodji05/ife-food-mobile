import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../../../shared/widgets/contact_support_sheet.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/route_params.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../../../../shared/widgets/theme_selector_tile.dart';
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
      backgroundColor: context.bgColor,
      appBar: AppBar(title: const Text('Mon Profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Establishment card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2E8B57)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                child: Center(child: Text(pro?.categoryEmoji ?? '🏪', style: const TextStyle(fontSize: 28)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pro?.businessName ?? 'Mon établissement', style: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 2),
                Text(user?.displayName ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8))),
              ])),
              if (pro != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(pro.statusLabel, style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
            if (pro != null) ...[
              const SizedBox(height: 16),
              Divider(color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 12),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 14, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 6),
                Expanded(child: Text(pro.address ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8)))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.phone_rounded, size: 14, color: Colors.white.withOpacity(0.8)),
                const SizedBox(width: 6),
                Text(pro.phone ?? user?.phone ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8))),
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
          _Item(Icons.store_rounded, 'Modifier mes informations', () => context.push('/pro/edit-info')),
          _Item(Icons.schedule_rounded, 'Horaires d\'ouverture', () => context.push('/pro/schedule')),
        ]),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: ThemeSelectorTile(darkSurface: context.isDark),
        ),
        const SizedBox(height: 12),

        _Section('Compte', [
          _Item(Icons.lock_rounded, 'Modifier le PIN', onTap: () {
            final phone = user?.phone;
            if (phone == null || phone.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Téléphone manquant — reconnectez-vous.'),
                backgroundColor: AppColors.danger,
              ));
              return;
            }
            context.push('/auth/pin', extra: PinRouteParams(mode: 'set', phone: phone));
          }),
          _Item(Icons.badge_rounded, 'Mes documents', onTap: () => context.push('/pro/documents')),
          _Item(Icons.notifications_rounded, 'Notifications', onTap: () => context.push('/pro/notifications')),
          _Item(Icons.notifications_active_rounded, 'État des notifications', onTap: () => FcmService.showDiagnosticDialog(context, ref)),
        ]),
        const SizedBox(height: 12),

        _Section('Aide & Légal', [
          _Item(Icons.support_agent_rounded, 'Contacter le support', onTap: () => showContactSupportSheet(context, ref, whatsappContext: "Bonjour, j'ai besoin d'aide avec mon compte ifè PRO.")),
          _Item(Icons.description_rounded, 'Charte du professionnel', onTap: () => context.push('/legal/PRO_CHARTER')),
          _Item(Icons.privacy_tip_rounded, 'Politique de confidentialité', onTap: () => context.push('/legal/PRIVACY')),
          _Item(Icons.gavel_rounded, "Conditions d'utilisation", onTap: () => context.push('/legal/CGU')),
          _Item(Icons.info_rounded, 'À propos', onTap: () => context.push('/legal/ABOUT')),
        ]),
        const SizedBox(height: 12),

        _Section('Danger', [
          _Item(Icons.logout_rounded, 'Se déconnecter', danger: true,
            onTap: () async { await ref.read(authProvider.notifier).logout(); if (context.mounted) context.go('/onboarding'); }),
        ]),
        const SizedBox(height: 24),
        Center(child: Text('ifè PRO v1.0.0 • Ets SWK FAKEYE',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted))),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// Supprimé : _showSupportSheet → remplacé par showContactSupportSheet

class _Section extends StatelessWidget {
  final String title; final List<Widget> items;
  const _Section(this.title, this.items);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: context.textMuted, letterSpacing: 0.5))),
    Container(decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor.withOpacity(0.8))),
      child: Column(children: items.asMap().entries.map((e) => Column(children: [if (e.key > 0) const Divider(height: 1, indent: 54), e.value])).toList())),
  ]);
}

class _Item extends StatelessWidget {
  final IconData icon; final String label; final String? sub;
  final bool danger; final VoidCallback onTap;
  const _Item(this.icon, this.label, {this.sub, this.danger = false, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36,
      decoration: BoxDecoration(color: (danger ? AppColors.danger : AppColors.primary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: danger ? AppColors.danger : AppColors.primary, size: 18)),
    title: Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600,
      color: danger ? AppColors.danger : context.textPrimary)),
    subtitle: sub != null ? Text(sub!, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textMuted)) : null,
    trailing: Icon(Icons.chevron_right_rounded, color: context.borderColor, size: 20),
    onTap: onTap,
  );
}
