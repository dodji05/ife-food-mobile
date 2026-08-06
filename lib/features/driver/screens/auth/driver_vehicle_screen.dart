// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Driver onboarding : choix du véhicule
//
// Étape spécifique driver, imposée par le redirect (app_router.dart, section
// b2) dès que needsRoleSetup=true côté AuthState — pas de navigation
// manuelle pour y arriver (uniquement pour la transition interne vers
// driver-documents, elle-même autorisée par ce même redirect).
//
// Flow :
//   1. User choisit type de véhicule (Moto/Tricycle/Vélo/Voiture/À pied)
//   2. Si Moto/Tricycle/Voiture : plaque + déclaration d'assurance obligatoires
//      (à pied/vélo n'ont ni l'un ni l'autre)
//   3. POST /drivers/register {vehicleType, licensePlate?, isInsured?, zoneCity, zoneCountry, zoneRadiusKm}
//   4. Le backend crée le Driver avec status='PENDING' → user.status devient PENDING aussi
//   5. context.go('/auth/driver-documents') — upload obligatoire des documents
//      requis selon le véhicule ; markRoleSetupDone() y déclenchera ensuite
//      /auth/pending via le redirect (pas de context.go() manuel là non plus)
//
// Source UI : porté depuis ife-food-driver/features/auth/screens/register_screen.dart
// Adapté : zoneCity/Country en dur Cotonou/BJ (sera éditable plus tard).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
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
  bool? _isInsured;
  bool _loading = false;

  // Types de véhicule supportés (alignés sur enum VehicleType backend).
  // Ordre : du plus courant au moins courant en Afrique de l'Ouest.
  final _vehicles = const [
    {'id': 'MOTORCYCLE', 'label': 'Moto',     'emoji': '🛵', 'sub': 'Le plus courant'},
    {'id': 'TRICYCLE',   'label': 'Tricycle', 'emoji': '🛺', 'sub': 'Grandes livraisons'},
    {'id': 'BICYCLE',    'label': 'Vélo',     'emoji': '🚲', 'sub': 'Écologique'},
    {'id': 'CAR',        'label': 'Voiture',  'emoji': '🚗', 'sub': 'Grandes livraisons'},
    {'id': 'ON_FOOT',    'label': 'À pied',   'emoji': '🚶', 'sub': 'Courtes distances'},
  ];

  // Immatriculation + assurance requises uniquement pour les véhicules motorisés.
  bool get _requiresPlateAndInsurance =>
      _vehicle == 'MOTORCYCLE' || _vehicle == 'TRICYCLE' || _vehicle == 'CAR';

  bool get _isValid =>
      !_requiresPlateAndInsurance ||
      (_plate.text.trim().isNotEmpty && _isInsured != null);

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/drivers/register', data: {
        'vehicleType': _vehicle,
        if (_requiresPlateAndInsurance) ...{
          'licensePlate': _plate.text.trim(),
          'isInsured': _isInsured,
        },
        // Zone par défaut Cotonou — le user pourra l'ajuster depuis le
        // profil quand la feature "éditer ma zone" sera prête.
        'zoneCity': 'Cotonou',
        'zoneCountry': 'BJ',
        'zoneRadiusKm': 10,
      });
      if (!mounted) return;
      // Le Driver existe désormais → étape suivante : upload des documents
      // requis selon le véhicule (pièce d'identité, permis, assurance…)
      // avant de basculer sur /auth/pending.
      context.go('/auth/driver-documents');
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.bgColor,
    appBar: AppBar(
      backgroundColor: context.bgColor, elevation: 0,
      // Pas de back : étape obligatoire avant d'accéder au dashboard.
      automaticallyImplyLeading: false,
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
            onPressed: (_loading || !_isValid) ? null : _submit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Soumettre mon inscription',
                  style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          const SizedBox(height: 8),
          Text('Votre dossier sera vérifié sous 24h',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textMuted)),
        ]),
      ),
    ),
    body: ListView(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Votre véhicule',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 28,
              fontWeight: FontWeight.w900, color: context.textPrimary)),
          const SizedBox(height: 6),
          Text('Quel type de véhicule utilisez-vous pour livrer ?',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: context.textSecondary)),
          const SizedBox(height: 28),
        ]),
      ),
      // Liste des véhicules — sélection radio visuelle
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(children: [
          ..._vehicles.map((v) => GestureDetector(
            onTap: () => setState(() {
              _vehicle = v['id']!;
              // Reset : champs saisis pour un autre type de véhicule.
              _plate.clear();
              _isInsured = null;
            }),
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

          // Plaque + assurance : uniquement moto/tricycle/voiture.
          // À pied/vélo n'ont ni l'un ni l'autre — la pièce d'identité
          // suffira, demandée ensuite sur l'écran "Mes documents".
          if (_requiresPlateAndInsurance) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PLAQUE D\'IMMATRICULATION *',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: _plate,
                  onChanged: (_) => setState(() {}),
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                    fontWeight: FontWeight.w600, color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Ex: BJ 1234 AB',
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
                Text('Obligatoire — pour vérification par l\'admin',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    color: context.textMuted)),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VÉHICULE ASSURÉ ? *',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: context.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _InsuranceChoiceButton(
                    label: 'Oui', selected: _isInsured == true,
                    onTap: () => setState(() => _isInsured = true),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _InsuranceChoiceButton(
                    label: 'Non', selected: _isInsured == false,
                    onTap: () => setState(() => _isInsured = false),
                  )),
                ]),
                if (_isInsured == true) ...[
                  const SizedBox(height: 6),
                  Text('Un justificatif d\'assurance vous sera demandé ensuite dans "Mes documents"',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                      color: context.textMuted)),
                ],
              ],
            ),
          ],
        ]),
      ),
    ]),
  );
}

// ── Bouton oui/non pour la déclaration d'assurance ──────────────────────────
class _InsuranceChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _InsuranceChoiceButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withOpacity(0.12) : context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : context.borderColor,
          width: selected ? 2 : 1),
      ),
      child: Center(child: Text(label,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700,
          color: selected ? AppColors.primary : context.textPrimary))),
    ),
  );
}
