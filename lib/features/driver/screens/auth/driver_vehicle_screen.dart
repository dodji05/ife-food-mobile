// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver onboarding : choix du véhicule
//
// Sprint 4 : étape spécifique driver intercalée APRÈS /auth/complete-profile
// (qui crée le AppUser) et AVANT /auth/pending (qui attend la validation admin).
//
// Flow :
//   1. User choisit type de véhicule (Moto/Vélo/Voiture/À pied)
//   2. Saisit optionnellement la plaque (sauf "À pied")
//   3. POST /drivers/register {vehicleType, licensePlate, zoneCity, zoneCountry, zoneRadiusKm}
//   4. Le backend crée le Driver avec status='PENDING' → user.status devient PENDING aussi
//   5. context.go('/auth/pending') (puis redirect GoRouter prend le relais)
//
// Source UI : porté depuis ife-food-driver/features/auth/screens/register_screen.dart
// Adapté : zoneCity/Country en dur Cotonou/BJ (sera éditable plus tard).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

class DriverVehicleScreen extends ConsumerStatefulWidget {
  const DriverVehicleScreen({super.key});
  @override
  ConsumerState<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends ConsumerState<DriverVehicleScreen> {
  String _vehicle = 'MOTORCYCLE';
  final _plate = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/drivers/register', data: {
        'vehicleType': _vehicle,
        if (_vehicle != 'ON_FOOT' && _plate.text.trim().isNotEmpty)
          'licensePlate': _plate.text.trim(),
        // Zone par défaut Cotonou — le user pourra l'ajuster depuis le
        // profil quand la feature "éditer ma zone" sera prête.
        'zoneCity': 'Cotonou',
        'zoneCountry': 'BJ',
        'zoneRadiusKm': 10,
      });
      if (!mounted) return;
      // Le backend met user.status='PENDING'. Le redirect GoRouter va
      // détecter isPending et envoyer sur /auth/pending automatiquement.
      // On force quand même la nav pour ne pas dépendre du timing du
      // refreshProfile (qui n'est pas appelé ici).
      context.go('/auth/pending');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final List<Map<String, String>> vehicles = [
      {'id': 'MOTORCYCLE', 'label': t.driverVehicleMotorcycle, 'emoji': '🛵', 'sub': t.driverVehicleMotorcycleSub},
      {'id': 'BICYCLE',    'label': t.driverVehicleBicycle,    'emoji': '🚲', 'sub': t.driverVehicleBicycleSub},
      {'id': 'CAR',        'label': t.driverVehicleCar,        'emoji': '🚗', 'sub': t.driverVehicleCarSub},
      {'id': 'ON_FOOT',    'label': t.driverVehicleOnFoot,     'emoji': '🚶', 'sub': t.driverVehicleOnFootSub},
    ];
    return Scaffold(
    backgroundColor: context.bgColor,
    appBar: AppBar(
      backgroundColor: context.bgColor, elevation: 0,
      // Pas de back : étape obligatoire avant d'accéder au dashboard.
      automaticallyImplyLeading: false,
    ),
    body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.driverVehicleTitle,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 28,
            fontWeight: FontWeight.w900, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text(t.driverVehicleQuestion,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: context.textSecondary)),
        const SizedBox(height: 28),

        // Liste des véhicules — sélection radio visuelle
        Expanded(child: ListView(children: [
          ...vehicles.map((v) => GestureDetector(
            onTap: () => setState(() => _vehicle = v['id']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _vehicle == v['id']
                    ? AppColors.primary.withOpacity(0.12)
                    : context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _vehicle == v['id'] ? AppColors.primary : context.borderColor,
                  width: _vehicle == v['id'] ? 2 : 1),
              ),
              child: Row(children: [
                Text(v['emoji']!, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v['label']!,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                      fontWeight: FontWeight.w700, color: context.textPrimary)),
                  Text(v['sub']!,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: context.textSecondary)),
                ])),
                if (_vehicle == v['id'])
                  const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 22),
              ]),
            ),
          )),
          const SizedBox(height: 16),

          // Plaque d'immatriculation (cachée pour "À pied")
          if (_vehicle != 'ON_FOOT') Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.driverLicensePlate,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _plate,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w600, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: t.driverLicensePlateHint,
                  hintStyle: TextStyle(color: context.textMuted),
                  filled: true,
                  fillColor: context.cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.borderColor)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 6),
              Text(t.driverLicensePlateOptional,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  color: context.textMuted)),
            ],
          ),
        ])),

        // CTA submit
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : Text(t.driverSubmitRegistration,
                style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        const SizedBox(height: 12),
        Center(child: Text(
          t.driverFileReviewed24h,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
            color: context.textMuted))),
      ]),
    )),
  );
  }
}
