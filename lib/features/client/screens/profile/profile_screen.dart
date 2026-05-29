// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Profil client (spec 2.6)
//
// Sections :
//   • Informations personnelles — édition prénom/nom/email/avatar
//   • Adresses                  — CRUD + adresse par défaut + GPS
//   • Paiement                  — placeholder (paiement à la commande)
//   • Préférences               — notifications, langue, pays/devise
//   • Sécurité                  — PIN, biométrie
//   • Compte                    — déconnexion, suppression
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/route_params.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/country_currency_picker.dart';
import '../../../../shared/widgets/editable_avatar.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../../../../shared/widgets/theme_selector_tile.dart';

class ClientProfileScreen extends ConsumerStatefulWidget {
  const ClientProfileScreen({super.key});
  @override
  ConsumerState<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends ConsumerState<ClientProfileScreen> {
  static const _storage = FlutterSecureStorage();
  bool _notifEnabled   = true;
  bool _bioLoading     = false;
  bool _deleteLoading  = false;

  @override
  void initState() {
    super.initState();
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final v = await _storage.read(key: AppConstants.notifEnabledKey);
    if (mounted) setState(() => _notifEnabled = v != 'false');
  }

  Future<void> _toggleNotif(bool value) async {
    await _storage.write(
        key: AppConstants.notifEnabledKey, value: value ? 'true' : 'false');
    setState(() => _notifEnabled = value);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value) {
      final auth = LocalAuthentication();
      final available = await auth.canCheckBiometrics;
      if (!available) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Biométrie non disponible sur cet appareil'),
            backgroundColor: AppColors.error,
          ));
        }
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Confirmez pour activer le déverrouillage biométrique',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (!ok) return;
    }
    setState(() => _bioLoading = true);
    try {
      await ref.read(authProvider.notifier).completeProfile({'biometricEnabled': value});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(value ? 'Biométrie activée ✓' : 'Biométrie désactivée'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) { setState(() => _bioLoading = false); }
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer mon compte',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800)),
        content: const Text(
          'Cette action est irréversible. Toutes vos données (commandes, adresses, '
          'avis) seront définitivement supprimées.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleteLoading = true);
    try {
      await ApiClient.instance.delete('/users/me');
      await ref.read(authProvider.notifier).logout();
      if (mounted) { context.go('/onboarding'); }
    } catch (e) {
      if (mounted) {
        setState(() => _deleteLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(title: const Text('Mon Profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── User card ──────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2E8B57)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
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
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user?.displayName ?? 'Utilisateur',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 18,
                      fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 2),
              Text(user?.phone ?? '',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: Colors.white.withOpacity(0.8))),
              if (user?.email != null && user!.email!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(user.email!,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: Colors.white.withOpacity(0.7))),
              ],
            ])),
            IconButton(
              onPressed: () => context.push('/profile/edit'),
              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              tooltip: 'Modifier mes infos',
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // ── Informations personnelles ──────────────────────────────────────
        _MenuSection(title: 'Informations personnelles', items: [
          _MenuItem(
            icon: Icons.person_rounded,
            label: 'Modifier mes infos',
            sub: 'Prénom, nom, email',
            onTap: () => context.push('/profile/edit'),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Adresses ──────────────────────────────────────────────────────
        _MenuSection(title: 'Adresses', items: [
          _MenuItem(
            icon: Icons.location_on_rounded,
            label: 'Mes adresses',
            sub: 'Ajout, modification, adresse par défaut',
            onTap: () => context.push('/addresses'),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Paiement ──────────────────────────────────────────────────────
        _MenuSection(title: 'Paiement', items: [
          _MenuItem(
            icon: Icons.payment_rounded,
            label: 'Moyens de paiement',
            sub: 'Paiement à la commande (KKiaPay, FedaPay, espèces…)',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Les moyens de paiement sont gérés à la commande'),
                duration: Duration(seconds: 3),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Préférences ────────────────────────────────────────────────────
        _MenuSection(title: 'Préférences', items: [
          _MenuToggle(
            icon: Icons.notifications_rounded,
            label: 'Notifications push',
            sub: _notifEnabled ? 'Activées' : 'Désactivées',
            value: _notifEnabled,
            onChanged: _toggleNotif,
          ),
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
            onTap: () => showCountryCurrencyPicker(context, ref,
                currentCountryCode: user?.countryCode ?? 'BJ', darkTheme: false),
          ),
        ]),
        const SizedBox(height: 8),
        // Apparence — hors _MenuSection car ConsumerWidget
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.lightGrey.withOpacity(0.8)),
          ),
          child: const ThemeSelectorTile(),
        ),
        const SizedBox(height: 12),

        // ── Sécurité ──────────────────────────────────────────────────────
        _MenuSection(title: 'Sécurité', items: [
          _MenuItem(
            icon: Icons.lock_rounded,
            label: 'Modifier mon PIN',
            sub: 'Code d\'accès à 4 chiffres',
            onTap: () => context.push('/auth/pin',
                extra: const PinRouteParams(mode: 'set')),
          ),
          _MenuToggle(
            icon: Icons.fingerprint_rounded,
            label: 'Déverrouillage biométrique',
            sub: (user?.biometricEnabled ?? false)
                ? 'Activé (empreinte / visage)'
                : 'Désactivé',
            value: user?.biometricEnabled ?? false,
            loading: _bioLoading,
            onChanged: _bioLoading ? null : _toggleBiometric,
          ),
        ]),
        const SizedBox(height: 12),

        // ── Aide & Légal ──────────────────────────────────────────────────
        _MenuSection(title: 'Aide & Légal', items: [
          _MenuItem(
            icon: Icons.support_agent_rounded,
            label: 'Contacter le support',
            onTap: () => _contactSupport(context),
          ),
          _MenuItem(
            icon: Icons.description_rounded,
            label: "Conditions d'utilisation",
            onTap: () => context.push('/legal/CGU'),
          ),
          _MenuItem(
            icon: Icons.privacy_tip_rounded,
            label: 'Politique de confidentialité',
            onTap: () => context.push('/legal/PRIVACY'),
          ),
          _MenuItem(
            icon: Icons.info_rounded,
            label: 'À propos',
            onTap: () => context.push('/legal/ABOUT'),
          ),
        ]),
        const SizedBox(height: 12),

        // ── Compte ─────────────────────────────────────────────────────────
        _MenuSection(title: 'Compte', items: [
          _MenuItem(
            icon: Icons.logout_rounded,
            label: 'Se déconnecter',
            danger: true,
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) { context.go('/onboarding'); }
            },
          ),
          _MenuItem(
            icon: _deleteLoading
                ? Icons.hourglass_empty_rounded
                : Icons.delete_forever_rounded,
            label: 'Supprimer mon compte',
            sub: 'Action irréversible',
            danger: true,
            onTap: _deleteLoading ? () {} : _deleteAccount,
          ),
        ]),

        const SizedBox(height: 24),
        Center(child: Text(
          'ifè FOOD v${AppConstants.appVersion} • Ets SWK FAKEYE',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.grey),
        )),
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(title,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                fontWeight: FontWeight.w700, color: AppColors.grey, letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.lightGrey.withOpacity(0.8)),
        ),
        child: Column(
          children: items.asMap().entries.map((e) => Column(children: [
            if (e.key > 0) const Divider(height: 1, indent: 54),
            e.value,
          ])).toList(),
        ),
      ),
    ],
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool danger;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon, required this.label, this.sub,
    this.danger = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: (danger ? AppColors.error : AppColors.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon,
          color: danger ? AppColors.error : AppColors.primary, size: 18),
    ),
    title: Text(label,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
            fontWeight: FontWeight.w600,
            color: danger ? AppColors.error : AppColors.nearBlack)),
    subtitle: sub != null
        ? Text(sub!,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: AppColors.grey))
        : null,
    trailing: const Icon(Icons.chevron_right_rounded,
        color: AppColors.lightGrey, size: 20),
    onTap: onTap,
  );
}

class _MenuToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? sub;
  final bool value;
  final bool loading;
  final ValueChanged<bool>? onChanged;
  const _MenuToggle({
    required this.icon, required this.label, this.sub,
    required this.value, required this.onChanged, this.loading = false,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppColors.primary, size: 18),
    ),
    title: Text(label,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
            fontWeight: FontWeight.w600, color: AppColors.nearBlack)),
    subtitle: sub != null
        ? Text(sub!,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: AppColors.grey))
        : null,
    trailing: loading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.primary))
        : Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
  );
}

// ── Contact support ────────────────────────────────────────────────────────

Future<void> _contactSupport(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Contacter le support',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                    fontWeight: FontWeight.w900, color: AppColors.nearBlack)),
          ),
        ),
        ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.chat_rounded,
                color: Color(0xFF25D366), size: 20),
          ),
          title: const Text('WhatsApp',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          subtitle: const Text('Réponse rapide en journée',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
          onTap: () async {
            Navigator.pop(ctx);
            await _openWhatsApp(context);
          },
        ),
        ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.email_rounded,
                color: AppColors.primary, size: 20),
          ),
          title: const Text('Email',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700)),
          subtitle: Text(AppConstants.supportEmail,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                  color: AppColors.grey)),
          onTap: () async {
            Navigator.pop(ctx);
            await _openEmail(context);
          },
        ),
        const SizedBox(height: 12),
      ]),
    ),
  );
}

Future<void> _openWhatsApp(BuildContext context) async {
  final uri = Uri.parse('https://wa.me/${AppConstants.supportWhatsapp}'
      '?text=${Uri.encodeComponent("Bonjour, j'ai besoin d'aide concernant l'app ifè FOOD.")}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Impossible d\'ouvrir WhatsApp'),
      backgroundColor: AppColors.error,
    ));
  }
}

Future<void> _openEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConstants.supportEmail,
    queryParameters: {
      'subject': 'Support ifè FOOD',
      'body': 'Bonjour,\n\nJe vous contacte concernant :\n\n',
    },
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Aucune app email configurée. Écrivez-nous à ${AppConstants.supportEmail}'),
      backgroundColor: AppColors.grey,
    ));
  }
}
