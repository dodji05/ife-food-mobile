// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Édition des infos établissement (pro)
//
// Pré-rempli depuis le state pro courant. PATCH /professionals/me avec uniquement
// les champs modifiés (delta) pour éviter d'écraser des champs serveur qu'on
// n'a pas chargé localement.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';

class EditBusinessInfoScreen extends ConsumerStatefulWidget {
  const EditBusinessInfoScreen({super.key});
  @override
  ConsumerState<EditBusinessInfoScreen> createState() => _State();
}

class _State extends ConsumerState<EditBusinessInfoScreen> {
  final _businessName = TextEditingController();
  final _description  = TextEditingController();
  final _address      = TextEditingController();
  final _city         = TextEditingController();
  final _phone        = TextEditingController();
  final _email        = TextEditingController();
  final _radius       = TextEditingController();
  bool _loading = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final pro = ref.read(proProvider).professional;
    if (pro == null) return;
    _businessName.text = pro.businessName;
    _description.text  = pro.description ?? '';
    _address.text      = pro.address ?? '';
    _city.text         = pro.city ?? '';
    _phone.text        = pro.phone ?? '';
    _email.text        = pro.email ?? '';
    _radius.text       = pro.deliveryRadiusKm != null
        ? pro.deliveryRadiusKm!.toStringAsFixed(pro.deliveryRadiusKm! % 1 == 0 ? 0 : 1)
        : '';
    _initialized = true;
  }

  @override
  void dispose() {
    _businessName.dispose();
    _description.dispose();
    _address.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    _radius.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_businessName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Le nom de l\'établissement est obligatoire'),
        backgroundColor: AppColors.danger,
      ));
      return;
    }
    setState(() => _loading = true);

    final pro = ref.read(proProvider).professional;
    // Construit un delta : seulement les champs modifiés. Évite d'envoyer
    // des champs vides qui écraseraient des valeurs serveur.
    final delta = <String, dynamic>{};
    void putIfChanged(String key, String? newVal, String? oldVal) {
      final v = newVal?.trim();
      // Toujours envoyer une valeur si modifiée (y compris vide → null backend).
      if (v != (oldVal ?? '')) {
        delta[key] = v == null || v.isEmpty ? null : v;
      }
    }
    putIfChanged('businessName', _businessName.text, pro?.businessName);
    putIfChanged('description',  _description.text,  pro?.description);
    putIfChanged('address',      _address.text,      pro?.address);
    putIfChanged('city',         _city.text,         pro?.city);
    putIfChanged('phone',        _phone.text,        pro?.phone);
    putIfChanged('email',        _email.text,        pro?.email);

    // deliveryRadiusKm : parsing en double, vide = null
    final radiusStr = _radius.text.trim().replaceAll(',', '.');
    final newRadius = radiusStr.isEmpty ? null : double.tryParse(radiusStr);
    if (newRadius != pro?.deliveryRadiusKm) {
      delta['deliveryRadiusKm'] = newRadius;
    }

    if (delta.isEmpty) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aucune modification à enregistrer'),
        backgroundColor: AppColors.darkSubtext,
      ));
      return;
    }

    try {
      await ref.read(proProvider.notifier).updateProfile(delta);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Informations mises à jour ✓'),
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBg,
    appBar: AppBar(title: const Text('Mes informations'), leading: const BackButton()),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const _Section('Établissement'),
      _Label("Nom de l'établissement *"),
      _TF(_businessName, 'Ex: Chez Maman Adèle'),
      const SizedBox(height: 16),
      _Label('Description (optionnel)'),
      _TF(_description, 'Spécialités, ambiance, à propos…', maxLines: 3),
      const SizedBox(height: 24),

      const _Section('Adresse'),
      _Label('Adresse'),
      _TF(_address, 'Ex: Carré 1234, Cotonou'),
      const SizedBox(height: 16),
      _Label('Ville'),
      _TF(_city, 'Ex: Cotonou'),
      const SizedBox(height: 16),
      _Label('Rayon de livraison (km)'),
      _TF(_radius, 'Ex: 5', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
      const SizedBox(height: 24),

      const _Section('Contact'),
      _Label('Téléphone'),
      _TF(_phone, 'Ex: +229 90 00 00 00', keyboardType: TextInputType.phone),
      const SizedBox(height: 16),
      _Label('Email'),
      _TF(_email, 'Ex: contact@etablissement.com', keyboardType: TextInputType.emailAddress),
      const SizedBox(height: 32),

      ElevatedButton(
        onPressed: _loading ? null : _save,
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Enregistrer les modifications'),
      ),
      const SizedBox(height: 40),
    ]),
  );
}

class _Section extends StatelessWidget {
  final String t;
  const _Section(this.t);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(t.toUpperCase(),
      style: const TextStyle(
        fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w800,
        color: AppColors.primary, letterSpacing: 1.0)),
  );
}

Widget _Label(String t) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(t,
    style: const TextStyle(
      fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.darkSubtext, letterSpacing: 0.3)),
);

Widget _TF(TextEditingController ctrl, String hint,
    {TextInputType? keyboardType, int? maxLines}) => TextField(
  controller: ctrl,
  keyboardType: keyboardType,
  maxLines: maxLines ?? 1,
  style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
      fontWeight: FontWeight.w600, color: AppColors.darkText),
  decoration: InputDecoration(hintText: hint),
);
