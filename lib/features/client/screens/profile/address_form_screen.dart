// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Client / Form add/edit adresse
//
// Mode CREATE : `addressId == null` (route /addresses/new)
// Mode EDIT   : `addressId != null` + `initial` Map (route /addresses/edit/:id)
//
// Champs :
//   - label (requis, suggestions chips : Maison/Bureau/Autre)
//   - address (requis, multiline 2 lignes)
//   - city (requis, défaut "Cotonou")
//   - instructions (optionnel, multiline 2 lignes)
//   - isDefault (switch ; pas affiché en mode CREATE si c'est la 1ère
//     adresse car backend la set auto en default)
//
// Bouton save fixé en bas via bottomNavigationBar (pattern hérité du
// pro/add-product : toujours visible peu importe scroll/clavier).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/utils/location_utils.dart';
import '../../providers/addresses_provider.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  /// `null` en mode create. ID adresse en mode edit.
  final String? addressId;
  /// Données initiales (uniquement en mode edit, depuis route extra).
  final Map<String, dynamic>? initial;

  const AddressFormScreen({super.key, this.addressId, this.initial});

  @override
  ConsumerState<AddressFormScreen> createState() => _State();
}

class _State extends ConsumerState<AddressFormScreen> {
  final _label   = TextEditingController();
  final _address = TextEditingController();
  final _city    = TextEditingController(text: 'Cotonou');
  final _instructions = TextEditingController();
  bool _isDefault = false;
  bool _loading = false;
  bool _geoLoading = false;
  double? _lat;
  double? _lng;

  bool get _isEdit => widget.addressId != null;

  bool get _canSave =>
      _label.text.trim().isNotEmpty &&
      _address.text.trim().isNotEmpty &&
      _city.text.trim().isNotEmpty &&
      !_loading;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final i = widget.initial!;
      _label.text        = (i['label']        as String?) ?? '';
      _address.text      = (i['address']      as String?) ?? '';
      _city.text         = (i['city']         as String?) ?? 'Cotonou';
      _instructions.text = (i['instructions'] as String?) ?? '';
      _isDefault         = (i['isDefault']    as bool?)   ?? false;
      _lat               = (i['lat']          as num?)?.toDouble();
      _lng               = (i['lng']          as num?)?.toDouble();
    }
  }

  @override
  void dispose() {
    _label.dispose();
    _address.dispose();
    _city.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _useGps() async {
    setState(() => _geoLoading = true);
    try {
      final granted = await ensureLocationPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Permission de localisation refusée'),
            backgroundColor: AppColors.error,
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
        if (_address.text.trim().isEmpty) {
          _address.text = 'Position GPS';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Position GPS capturée ✓'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Localisation impossible : ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) { setState(() => _geoLoading = false); }
    }
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _loading = true);
    try {
      final notifier = ref.read(addressesNotifierProvider);
      if (_isEdit) {
        await notifier.update(
          widget.addressId!,
          label:        _label.text.trim(),
          address:      _address.text.trim(),
          city:         _city.text.trim(),
          lat:          _lat,
          lng:          _lng,
          instructions: _instructions.text.trim(),
          isDefault:    _isDefault,
        );
      } else {
        await notifier.create(
          label:        _label.text.trim(),
          address:      _address.text.trim(),
          city:         _city.text.trim(),
          lat:          _lat,
          lng:          _lng,
          instructions: _instructions.text.trim().isEmpty ? null : _instructions.text.trim(),
          isDefault:    _isDefault,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Adresse modifiée ✓' : 'Adresse ajoutée ✓'),
        backgroundColor: AppColors.success,
      ));
      context.pop();
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
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier l\'adresse' : 'Nouvelle adresse'),
        leading: const BackButton(),
      ),
      // Bouton fixé en bas pour visibilité garantie (cf. pro/add-product).
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canSave ? _save : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text(
                      _isEdit ? 'Enregistrer les modifications' : 'Ajouter l\'adresse',
                      style: const TextStyle(
                        fontFamily: 'Nunito', fontSize: 15,
                        fontWeight: FontWeight.w800, color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // ── Label avec chips suggestions ─────────────────────────────────
        _Label('Étiquette *', context),
        const SizedBox(height: 8),
        _TF(_label, 'Ex: Maison, Bureau…', context, onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: ['Maison', 'Bureau', 'Autre'].map((sug) =>
          ActionChip(
            label: Text(sug, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12)),
            backgroundColor: AppColors.primary.withOpacity(0.08),
            side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
            onPressed: () => setState(() => _label.text = sug),
          ),
        ).toList()),
        const SizedBox(height: 20),

        _Label('Adresse complète *', context),
        const SizedBox(height: 8),
        _TF(_address, 'Ex: Carré 1234, Quartier Cadjèhoun', context, maxLines: 2,
            onChanged: (_) => setState(() {})),
        const SizedBox(height: 8),
        // Bouton GPS — remplit _lat/_lng et pré-remplit l'adresse si vide
        Row(children: [
          OutlinedButton.icon(
            onPressed: _geoLoading ? null : _useGps,
            icon: _geoLoading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Icon(Icons.my_location_rounded, size: 16),
            label: Text(
              _lat != null ? 'GPS capturé ✓' : 'Utiliser ma position GPS',
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _lat != null ? AppColors.success : AppColors.primary,
              side: BorderSide(color: _lat != null ? AppColors.success : AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_lat != null) ...[
            const SizedBox(width: 8),
            Expanded(child: Text(
              '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                  color: context.textMuted),
              overflow: TextOverflow.ellipsis,
            )),
          ],
        ]),
        const SizedBox(height: 16),

        _Label('Ville *', context),
        const SizedBox(height: 8),
        _TF(_city, 'Ex: Cotonou', context, onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),

        _Label('Instructions livreur (optionnel)', context),
        const SizedBox(height: 8),
        _TF(_instructions, 'Ex: Sonner 2 fois, code 1234, portail bleu', context,
            maxLines: 2),
        const SizedBox(height: 20),

        // ── Toggle isDefault ─────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor),
          ),
          child: Row(children: [
            const Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Adresse par défaut',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w700, color: context.textPrimary)),
              Text('Sélectionnée automatiquement au checkout',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
            ])),
            Switch(
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              activeColor: AppColors.primary,
            ),
          ]),
        ),
        const SizedBox(height: 12),
      ]),
    );
  }
}

Widget _Label(String t, BuildContext context) => Text(t,
  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
      fontWeight: FontWeight.w700, color: context.textSecondary, letterSpacing: 0.3));

Widget _TF(TextEditingController ctrl, String hint, BuildContext context,
    {int? maxLines, void Function(String)? onChanged}) => TextField(
  controller: ctrl,
  maxLines: maxLines ?? 1,
  onChanged: onChanged,
  textCapitalization: TextCapitalization.sentences,
  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
      fontWeight: FontWeight.w600, color: context.textPrimary),
  decoration: InputDecoration(hintText: hint),
);
