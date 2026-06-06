import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/notifications/fcm_service.dart';
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
            gradient: LinearGradient(colors: [const Color(0xFF0A2030), context.cardColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 56, height: 56, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                child: Center(child: Text(pro?.categoryEmoji ?? '🏪', style: const TextStyle(fontSize: 28)))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(pro?.businessName ?? 'Mon établissement', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w900, color: context.textPrimary)),
                const SizedBox(height: 2),
                Text(user?.displayName ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
              ])),
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
              Divider(color: context.borderColor),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(pro.address ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.phone_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(pro.phone ?? user?.phone ?? '', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary)),
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
          child: const ThemeSelectorTile(darkSurface: true),
        ),
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
            context.push('/auth/pin', extra: PinRouteParams(mode: 'set', phone: phone));
          }),
          // TODO: réactiver quand la gestion multilingue est finalisée
          // _Item(Icons.language_rounded, 'Langue',
          //     () => showLanguagePicker(context, ref, currentLang: user?.lang ?? 'fr', darkTheme: true)),
          _Item(Icons.badge_rounded, 'Mes documents', () => context.push('/pro/documents')),
          _Item(Icons.notifications_rounded, 'Notifications', () => context.push('/pro/notifications')),
          _Item(Icons.notifications_active_rounded, 'État des notifications', () => FcmService.showDiagnosticDialog(context, ref)),
        ]),
        const SizedBox(height: 12),

        _Section('Aide & Légal', [
          _Item(Icons.support_agent_rounded, 'Contacter le support', () => _showSupportSheet(context)),
          _Item(Icons.description_rounded, 'Charte du professionnel', () => context.push('/legal/professional-charter')),
          _Item(Icons.privacy_tip_rounded, 'Politique de confidentialité', () => context.push('/legal/privacy')),
          _Item(Icons.gavel_rounded, 'Conditions générales', () => context.push('/legal/terms')),
        ]),
        const SizedBox(height: 12),

        Container(
          decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Se déconnecter', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.danger)),
            onTap: () async { await ref.read(authProvider.notifier).logout(); if (context.mounted) context.go('/onboarding'); },
          ),
        ),
        const SizedBox(height: 40),
        Text('ifè PRO v1.0.0 • Ets SWK FAKEYE', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
        const SizedBox(height: 20),
      ]),
    );
  }
}

void _showSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: sheetCtx.borderColor, borderRadius: BorderRadius.circular(2))),
          Text('Contacter le support', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w900, color: sheetCtx.textPrimary)),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18)),
            title: Text('WhatsApp', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: sheetCtx.textPrimary)),
            subtitle: Text('+229 90 00 00 00', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: sheetCtx.textSecondary)),
            onTap: () async {
              final uri = Uri.parse('https://wa.me/${AppConstants.supportWhatsapp}?text=Bonjour%2C%20j%27ai%20besoin%20d%27aide%20avec%20mon%20compte%20ifè%20PRO.');
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.email_rounded, color: AppColors.primary, size: 18)),
            title: Text('Email', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: sheetCtx.textPrimary)),
            subtitle: Text(AppConstants.supportEmail, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: sheetCtx.textSecondary)),
            onTap: () async {
              final uri = Uri(scheme: 'mailto', path: AppConstants.supportEmail, queryParameters: {'subject': 'Support ifè PRO'});
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ),
  );
}

class _Section extends StatelessWidget {
  final String title; final List<_Item> items;
  const _Section(this.title, this.items);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text(title, style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: context.textSecondary, letterSpacing: 0.5))),
    Container(decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.borderColor)),
      child: Column(children: items.asMap().entries.map((e) => Column(children: [if (e.key > 0) Divider(height: 1, color: context.borderColor, indent: 54), e.value])).toList())),
  ]);
}

class _Item extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _Item(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 18)),
    title: Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
    trailing: Icon(Icons.chevron_right_rounded, color: context.textMuted, size: 18),
    onTap: onTap,
  );
}
