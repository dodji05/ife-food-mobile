// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver / Profil
//
// Sprint 2 : enrichi depuis ife-food-driver/features/profile/screens/profile_screen.dart
//   - Hero card avec avatar éditable + badge online dot + badge véhicule
//   - Banner "Compte en attente de validation" si driver.isPending
//   - Section Compte : véhicule (read-only), zone, PIN, langue, notif
//   - Section Documents : pièce d'identité, permis (statut depuis driver.documents)
//   - Section Aide & Légal : support WhatsApp/Email, charte, confidentialité
//
// Préserve : EditableAvatar, language_picker dark, PinRouteParams, deep link
// notifications. Ajoute : badge online, états doc dynamiques, contact support.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/router/route_params.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/driver.dart';
import '../../../../shared/widgets/editable_avatar.dart';
import '../../../../shared/widgets/language_picker.dart';
import '../../../../shared/widgets/theme_selector_tile.dart';
import '../../providers/driver_provider.dart';
import 'driver_zones_screen.dart';
import 'driver_documents_screen.dart';

class DriverProfileScreen extends ConsumerWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final driverState = ref.watch(driverProvider);
    final driver = driverState.driver;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(title: const Text('Mon profil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── Hero card ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D3320), AppColors.darkCard],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
          ),
          child: Column(children: [
            // Avatar + dot online en bas-droite
            Stack(children: [
              EditableAvatar(
                currentUrl: user?.avatarUrl,
                fallbackText: user?.displayName ?? '?',
                radius: 36,
                backgroundColor: AppColors.primary.withOpacity(0.2),
                textColor: AppColors.primary,
              ),
              Positioned(bottom: 0, right: 0, child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: driverState.isOnline ? AppColors.success : AppColors.darkMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkCard, width: 2),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            Text(user?.displayName ?? 'Livreur',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 20,
                fontWeight: FontWeight.w900, color: AppColors.darkText)),
            const SizedBox(height: 2),
            Text(user?.phone ?? '',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
                color: AppColors.darkSubtext)),
            const SizedBox(height: 12),
            // Badge véhicule (lit driver.vehicleEmoji + vehicleType)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.primary.withOpacity(0.3))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(driver?.vehicleEmoji ?? '🛵', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(_vehicleLabel(driver?.vehicleType),
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Banner statut pending (compte en validation)
        if (driver?.isPending == true) Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.info.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Text('⏳', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Votre compte est en cours de validation par notre équipe. '
              'Vous recevrez une notification dès qu\'il sera actif.',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                color: AppColors.info, height: 1.4))),
          ]),
        ),

        // Banner suspended (compte suspendu — contact support)
        if (driver?.isSuspended == true) Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.danger.withOpacity(0.3)),
          ),
          child: const Row(children: [
            Text('🚫', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Votre compte est suspendu. Contactez le support pour plus d\'informations.',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                color: AppColors.danger, height: 1.4))),
          ]),
        ),

        // ── Compte ────────────────────────────────────────────────────────
        _Section('Compte', [
          _Item(Icons.directions_bike_rounded, 'Mon véhicule',
              sub: _vehicleLabel(driver?.vehicleType) +
                  (driver?.licensePlate != null ? ' • ${driver!.licensePlate}' : ''),
              onTap: () => _showVehicleSheet(context, ref, driver)),
          _Item(Icons.location_city_rounded, 'Zones de livraison',
              sub: 'Gérer mes zones d\'activité',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DriverZonesScreen()))),
          _Item(Icons.lock_rounded, 'Modifier le PIN', onTap: () {
            final phone = user?.phone;
            if (phone == null || phone.isEmpty) return;
            context.push('/auth/pin', extra: PinRouteParams(mode: 'set', phone: phone));
          }),
          _Item(Icons.notifications_rounded, 'Mes notifications',
              onTap: () => context.push('/driver/notifications')),
          _Item(Icons.language_rounded, 'Langue',
              sub: _langLabel(user?.lang ?? 'fr'),
              onTap: () => showLanguagePicker(context, ref,
                  currentLang: user?.lang ?? 'fr', darkTheme: true)),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.driverCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.driverBorder),
          ),
          child: const ThemeSelectorTile(darkSurface: true),
        ),
        const SizedBox(height: 12),

        // ── Documents ─────────────────────────────────────────────────────
        _Section('Documents', [
          _Item(Icons.folder_copy_rounded, 'Mes documents',
              sub: 'Pièce d\'identité, permis de conduire',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const DriverDocumentsScreen()))),
        ]),
        const SizedBox(height: 12),

        // ── Aide & Légal ─────────────────────────────────────────────────
        _Section('Aide & Légal', [
          _Item(Icons.support_agent_rounded, 'Contacter le support',
              onTap: () => _contactSupport(context)),
          _Item(Icons.description_rounded, 'Charte du livreur',
              onTap: () => context.push('/legal/CGU')),
          _Item(Icons.privacy_tip_rounded, 'Politique de confidentialité',
              onTap: () => context.push('/legal/PRIVACY')),
          _Item(Icons.info_rounded, 'À propos',
              onTap: () => context.push('/legal/ABOUT')),
        ]),
        const SizedBox(height: 12),

        // ── Logout ────────────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: const Text('Se déconnecter',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                fontWeight: FontWeight.w700, color: AppColors.danger)),
            onTap: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/onboarding');
            },
          ),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('ifè Livreur v1.0.0 • Ets SWK FAKEYE',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkMuted))),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ── Helpers labels ─────────────────────────────────────────────────────
  String _vehicleLabel(String? type) => switch (type) {
    'MOTORCYCLE' => 'Moto',
    'CAR'        => 'Voiture',
    'BICYCLE'    => 'Vélo',
    'ON_FOOT'    => 'À pied',
    _            => 'Moto',
  };

  String _langLabel(String code) => switch (code) {
    'fr' => 'Français',
    'en' => 'English',
    'fon' => 'Fɔngbe',
    'yo' => 'Yorùbá',
    _ => code,
  };

}

// ── Bottom sheet modification véhicule ───────────────────────────────────────
Future<void> _showVehicleSheet(
    BuildContext context, WidgetRef ref, driver) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VehicleSheet(
      currentType:  driver?.vehicleType ?? 'MOTORCYCLE',
      currentPlate: driver?.licensePlate,
      onSaved: () => ref.invalidate(driverProvider),
    ),
  );
}

// ── Bottom sheet contact support (WhatsApp / Email) ──────────────────────
Future<void> _contactSupport(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.darkCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.darkBorder,
            borderRadius: BorderRadius.circular(2)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(alignment: Alignment.centerLeft, child: Text(
            'Contacter le support',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
              fontWeight: FontWeight.w900, color: AppColors.darkText))),
        ),
        ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withOpacity(0.18),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 20),
          ),
          title: const Text('WhatsApp',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.darkText)),
          subtitle: const Text('Réponse rapide en journée',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
          onTap: () async {
            Navigator.pop(sheetCtx);
            await _openWhatsApp(context);
          },
        ),
        ListTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.email_rounded, color: AppColors.primary, size: 20),
          ),
          title: const Text('Email',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.darkText)),
          subtitle: Text(AppConstants.supportEmail,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
          onTap: () async {
            Navigator.pop(sheetCtx);
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
      '?text=${Uri.encodeComponent("Bonjour, je suis livreur ifè FOOD et j'ai besoin d'aide.")}');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Impossible d\'ouvrir WhatsApp'),
      backgroundColor: AppColors.danger,
    ));
  }
}

Future<void> _openEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConstants.supportEmail,
    queryParameters: {
      'subject': 'Support ifè FOOD — Livreur',
      'body': 'Bonjour,\n\nJe suis livreur ifè FOOD et je vous contacte concernant :\n\n',
    },
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Aucune app email configurée. Écrivez-nous à ${AppConstants.supportEmail}'),
      backgroundColor: AppColors.darkMuted,
    ));
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
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
          fontWeight: FontWeight.w800, color: AppColors.darkSubtext, letterSpacing: 0.5)),
    ),
    Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.darkBorder)),
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
  final String? sub;
  final VoidCallback onTap;
  const _Item(this.icon, this.label, {this.sub, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: AppColors.primary, size: 18),
    ),
    title: Text(label,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
        fontWeight: FontWeight.w600, color: AppColors.darkText)),
    subtitle: sub != null ? Text(sub!,
      style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)) : null,
    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.darkMuted, size: 18),
    onTap: onTap,
  );
}

// ── Bottom sheet modification véhicule ────────────────────────────────────────
class _VehicleSheet extends ConsumerStatefulWidget {
  final String currentType;
  final String? currentPlate;
  final VoidCallback onSaved;
  const _VehicleSheet({
    required this.currentType,
    required this.currentPlate,
    required this.onSaved,
  });
  @override
  ConsumerState<_VehicleSheet> createState() => _VehicleSheetState();
}

class _VehicleSheetState extends ConsumerState<_VehicleSheet> {
  late String _type;
  late final TextEditingController _plate;
  bool _loading = false;

  static const _vehicles = [
    ('MOTORCYCLE', '🛵', 'Moto'),
    ('CAR',        '🚗', 'Voiture'),
    ('BICYCLE',    '🚲', 'Vélo'),
    ('ON_FOOT',    '🚶', 'À pied'),
  ];

  bool get _plateRequired =>
      _type == 'MOTORCYCLE' || _type == 'CAR';

  bool get _isValid =>
      !_plateRequired || _plate.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _type  = widget.currentType;
    _plate = TextEditingController(text: widget.currentPlate ?? '');
  }

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.patch('/drivers/me', data: {
        'vehicleType':  _type,
        'licensePlate': _plateRequired ? _plate.text.trim() : null,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Drag handle
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.darkBorder,
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Mon véhicule',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                fontWeight: FontWeight.w900, color: AppColors.darkText)),
          const SizedBox(height: 20),

          // Sélecteur type de véhicule
          Row(children: _vehicles.map((v) {
            final (id, emoji, label) = v;
            final selected = _type == id;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() {
                _type = id;
                if (!_plateRequired) _plate.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.15)
                      : AppColors.darkBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : AppColors.darkBorder,
                    width: selected ? 2 : 1),
                ),
                child: Column(children: [
                  Text(emoji,
                    style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 4),
                  Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primary
                          : AppColors.darkSubtext)),
                ]),
              ),
            ));
          }).toList()),

          // Champ immatriculation (requis pour moto/voiture)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _plateRequired
                ? Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextField(
                      controller: _plate,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(
                          fontFamily: 'Nunito',
                          color: AppColors.darkText,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5),
                      decoration: InputDecoration(
                        labelText: 'Immatriculation *',
                        labelStyle: const TextStyle(
                            fontFamily: 'Nunito',
                            color: AppColors.darkSubtext,
                            fontSize: 13),
                        hintText: 'ex : AB 1234 BJ',
                        prefixIcon: const Icon(
                            Icons.pin_rounded,
                            color: AppColors.darkSubtext,
                            size: 18),
                        filled: true,
                        fillColor: AppColors.darkBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.darkBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.darkBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5)),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: (_isValid && !_loading) ? _save : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle: const TextStyle(
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  fontSize: 15)),
            child: _loading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Enregistrer'),
          ),
        ]),
      ),
    );
  }
}
