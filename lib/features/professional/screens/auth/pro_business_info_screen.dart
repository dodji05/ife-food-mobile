// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Pro onboarding : infos établissement
//
// Étape spécifique pro intercalée APRÈS /auth/complete-profile (qui crée le
// AppUser) et AVANT /auth/pending (qui attend la validation admin). Symétrique
// de /auth/driver-vehicle côté livreur.
//
// Flow :
//   1. User saisit nom établissement, catégorie, adresse, ville, GPS
//   2. IFU / RCCM optionnels (déclaratifs, vérifiables plus tard par l'admin)
//   3. POST /professionals/register {businessName, category, address, city,
//      country, lat, lng, ifu?, rccm?}
//   4. Le backend crée le Professional avec status='PENDING' → user.status
//      devient PENDING aussi (déjà le cas depuis l'inscription OTP)
//   5. context.go('/auth/pending') (puis redirect GoRouter prend le relais)
//
// Contrairement à l'ancien flow (fiche créée en douce au 1er accès dashboard,
// avec businessName placeholder "Mon établissement"), la fiche existe
// désormais dès l'inscription, avec de vraies données.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/utils/location_utils.dart';

class ProBusinessInfoScreen extends ConsumerStatefulWidget {
  const ProBusinessInfoScreen({super.key});
  @override
  ConsumerState<ProBusinessInfoScreen> createState() => _ProBusinessInfoScreenState();
}

class _ProBusinessInfoScreenState extends ConsumerState<ProBusinessInfoScreen> {
  final _businessName = TextEditingController();
  final _address       = TextEditingController();
  final _city          = TextEditingController();
  final _ifu           = TextEditingController();
  final _rccm          = TextEditingController();
  String _category = 'RESTAURANT';
  double? _lat;
  double? _lng;
  bool _geoLoading = false;
  bool _loading = false;

  static const _categories = [
    {'id': 'RESTAURANT',  'label': 'Restaurant',    'emoji': '🍽️'},
    {'id': 'GROCERY',     'label': 'Épicerie',      'emoji': '🛒'},
    {'id': 'SUPERMARKET', 'label': 'Supermarché',   'emoji': '🏪'},
    {'id': 'BAKERY',      'label': 'Boulangerie',   'emoji': '🥖'},
    {'id': 'PHARMACY',    'label': 'Pharmacie',     'emoji': '💊'},
    {'id': 'OTHER',       'label': 'Autre',         'emoji': '🏬'},
  ];

  bool get _isValid =>
      _businessName.text.trim().isNotEmpty &&
      _address.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      _lat != null && _lng != null;

  @override
  void dispose() {
    _businessName.dispose();
    _address.dispose();
    _city.dispose();
    _ifu.dispose();
    _rccm.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _geoLoading = true);
    try {
      final granted = await ensureLocationPermission();
      if (!granted) {
        if (mounted) _snack('Permission de localisation refusée', error: true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });
      if (mounted) _snack('Position GPS capturée ✓');
    } catch (e) {
      if (mounted) _snack('Localisation impossible : ${e.toString().replaceAll('Exception: ', '')}', error: true);
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _loading = true);
    try {
      await ApiClient.instance.post('/professionals/register', data: {
        'businessName': _businessName.text.trim(),
        'category': _category,
        'address': _address.text.trim(),
        'city': _city.text.trim(),
        'country': 'BJ',
        'lat': _lat,
        'lng': _lng,
        if (_ifu.text.trim().isNotEmpty) 'ifu': _ifu.text.trim(),
        if (_rccm.text.trim().isNotEmpty) 'rccm': _rccm.text.trim(),
      });
      if (!mounted) return;
      // Le backend met user.status='PENDING'. Le redirect GoRouter va
      // détecter isPending et envoyer sur /auth/pending automatiquement.
      context.go('/auth/pending');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceAll('Exception: ', ''), error: true);
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
    body: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 0), children: [
      Text('Votre établissement',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 28,
          fontWeight: FontWeight.w900, color: context.textPrimary)),
      const SizedBox(height: 6),
      Text('Parlez-nous de votre commerce',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 15, color: context.textSecondary)),
      const SizedBox(height: 28),

      _label('NOM DE L\'ÉTABLISSEMENT *', context),
      const SizedBox(height: 8),
      _textField(_businessName, 'Ex: Chez Maman Adèle', context),
      const SizedBox(height: 20),

      _label('CATÉGORIE *', context),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
        final selected = _category == c['id'];
        return GestureDetector(
          onTap: () => setState(() => _category = c['id']!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withOpacity(0.12) : context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : context.borderColor,
                width: selected ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(c['emoji']!, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(c['label']!,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primary : context.textPrimary)),
            ]),
          ),
        );
      }).toList()),
      const SizedBox(height: 20),

      _label('ADRESSE *', context),
      const SizedBox(height: 8),
      _textField(_address, 'Ex: Carré 1234, Cotonou', context),
      const SizedBox(height: 20),

      _label('VILLE *', context),
      const SizedBox(height: 8),
      _textField(_city, 'Ex: Cotonou', context),
      const SizedBox(height: 20),

      _label('LOCALISATION GPS *', context),
      const SizedBox(height: 8),
      Row(children: [
        OutlinedButton.icon(
          onPressed: _geoLoading ? null : _useGps,
          icon: _geoLoading
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
              : const Icon(Icons.my_location_rounded, size: 16),
          label: Text(
            _lat != null ? 'GPS enregistré ✓' : 'Utiliser ma position actuelle',
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _lat != null ? AppColors.success : AppColors.primary,
            side: BorderSide(color: _lat != null ? AppColors.success : context.borderColor),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (_lat != null) ...[
          const SizedBox(width: 10),
          Expanded(child: Text(
            '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textSecondary),
            overflow: TextOverflow.ellipsis,
          )),
        ],
      ]),
      const SizedBox(height: 6),
      Text('Obligatoire — permet aux clients de vous localiser',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
      const SizedBox(height: 28),

      Divider(color: context.borderColor),
      const SizedBox(height: 20),
      Text('Documents légaux (optionnel)',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800,
          color: context.textPrimary)),
      const SizedBox(height: 4),
      Text('Peuvent être complétés plus tard, mais accélèrent la validation',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
      const SizedBox(height: 16),

      _label('IFU', context),
      const SizedBox(height: 8),
      _textField(_ifu, 'Identifiant Fiscal Unique', context),
      const SizedBox(height: 20),

      _label('RCCM', context),
      const SizedBox(height: 8),
      _textField(_rccm, 'Registre du Commerce et du Crédit Mobilier', context),
      const SizedBox(height: 40),
    ]),
  );

  Widget _label(String t, BuildContext context) => Text(t,
    style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800,
      color: context.textSecondary, letterSpacing: 0.5));

  Widget _textField(TextEditingController ctrl, String hint, BuildContext context) => TextField(
    controller: ctrl,
    onChanged: (_) => setState(() {}),
    style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600,
      color: context.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
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
  );
}
