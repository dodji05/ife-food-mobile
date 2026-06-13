import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../core/utils/location_utils.dart';
import '../../client/providers/addresses_provider.dart';

class SetupAddressScreen extends ConsumerStatefulWidget {
  final String? returnTo;
  const SetupAddressScreen({super.key, this.returnTo});
  @override
  ConsumerState<SetupAddressScreen> createState() => _State();
}

class _State extends ConsumerState<SetupAddressScreen> {
  final _label   = TextEditingController(text: 'Maison');
  final _address = TextEditingController();
  final _city    = TextEditingController(text: 'Cotonou');

  double? _lat;
  double? _lng;
  bool _geoLoading = false;
  bool _saving     = false;

  bool get _canSave =>
      _lat != null &&
      _lng != null &&
      _label.text.trim().isNotEmpty &&
      _address.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      !_saving;

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _localize() async {
    setState(() => _geoLoading = true);
    try {
      final granted = await ensureLocationPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission de localisation refusée. Activez-la dans les paramètres.'),
            backgroundColor: AppColors.danger,
            duration: Duration(seconds: 4),
          ));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (_address.text.trim().isEmpty) _address.text = 'Ma position';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Localisation impossible : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _geoLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await ref.read(addressesNotifierProvider).create(
        label:   _label.text.trim(),
        address: _address.text.trim(),
        city:    _city.text.trim(),
        lat:     _lat,
        lng:     _lng,
        isDefault: true,
      );
      if (mounted) context.go(widget.returnTo ?? '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gpsOk = _lat != null && _lng != null;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Adresse de livraison',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800,
              color: Colors.white, fontSize: 17)),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: ElevatedButton(
            onPressed: _canSave ? _save : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Continuer',
                    style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                        fontSize: 16, color: Colors.white)),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          Text('Où souhaitez-vous être livré ?',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 24,
                fontWeight: FontWeight.w900, color: context.textPrimary)),
          const SizedBox(height: 8),
          Text('Votre position est utilisée pour trouver les établissements proches '
              'et calculer les frais de livraison.',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                color: context.textSecondary, height: 1.5)),

          const SizedBox(height: 32),

          // ── Bouton GPS ──────────────────────────────────────────────────
          GestureDetector(
            onTap: _geoLoading ? null : _localize,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              decoration: BoxDecoration(
                color: gpsOk
                    ? AppColors.success.withOpacity(0.10)
                    : AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: gpsOk ? AppColors.success : AppColors.primary,
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: (gpsOk ? AppColors.success : AppColors.primary).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: _geoLoading
                      ? Padding(
                          padding: const EdgeInsets.all(14),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.primary,
                          ))
                      : Icon(
                          gpsOk ? Icons.location_on_rounded : Icons.my_location_rounded,
                          color: gpsOk ? AppColors.success : AppColors.primary,
                          size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    gpsOk ? 'Position capturée ✓' : 'Me localiser',
                    style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800,
                      color: gpsOk ? AppColors.success : AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    gpsOk
                        ? 'Lat: ${_lat!.toStringAsFixed(5)}, Lng: ${_lng!.toStringAsFixed(5)}'
                        : 'Appuyez pour détecter votre position GPS',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: context.textSecondary),
                  ),
                ])),
                if (!gpsOk && !_geoLoading)
                  Icon(Icons.chevron_right_rounded, color: AppColors.primary),
              ]),
            ),
          ),

          // ── Champs (visibles uniquement après GPS) ───────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: gpsOk ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 28),

              _label_widget('Libellé de l\'adresse *'),
              const SizedBox(height: 8),
              _chips(),
              const SizedBox(height: 8),
              _tf(_label, 'Ex : Maison, Bureau…'),

              const SizedBox(height: 20),
              _label_widget('Adresse *'),
              const SizedBox(height: 8),
              _tf(_address, 'Ex : Quartier Cadjèhoun, Rue 12…', maxLines: 2),

              const SizedBox(height: 20),
              _label_widget('Ville *'),
              const SizedBox(height: 8),
              _tf(_city, 'Cotonou'),

              const SizedBox(height: 12),
            ]),
          ),

          if (!gpsOk) ...[
            const SizedBox(height: 32),
            Center(child: Text(
              'La géolocalisation est requise pour continuer.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: context.textMuted, fontStyle: FontStyle.italic),
            )),
          ],
        ]),
      ),
    );
  }

  Widget _label_widget(String text) => Text(text,
    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
        fontWeight: FontWeight.w700, color: context.textSecondary, letterSpacing: 0.3));

  Widget _chips() => Wrap(spacing: 8, children: [
    for (final l in ['Maison', 'Bureau', 'Autre'])
      GestureDetector(
        onTap: () => setState(() => _label.text = l),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _label.text == l
                ? AppColors.primary
                : context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _label.text == l ? AppColors.primary : context.borderColor),
          ),
          child: Text(l, style: TextStyle(
            fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
            color: _label.text == l ? Colors.white : context.textSecondary)),
        ),
      ),
  ]);

  Widget _tf(TextEditingController ctrl, String hint, {int maxLines = 1}) => TextField(
    controller: ctrl,
    maxLines: maxLines,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600),
    decoration: InputDecoration(hintText: hint),
  );
}
