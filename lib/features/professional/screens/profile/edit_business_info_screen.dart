// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Édition des infos établissement (pro)
//
// Pré-rempli depuis le state pro courant. PATCH /professionals/me avec uniquement
// les champs modifiés (delta) pour éviter d'écraser des champs serveur qu'on
// n'a pas chargé localement.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  bool _uploadingLogo  = false;
  bool _uploadingCover = false;

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

  // ── Upload helpers (logo + cover) ─────────────────────────────────────────
  /// Affiche un bottom sheet caméra/galerie, retourne le `File` choisi ou null.
  Future<File?> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.darkCard,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
          title: const Text('Choisir depuis la galerie',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.darkText)),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        ListTile(
          leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
          title: const Text('Prendre une photo',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, color: AppColors.darkText)),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        const SizedBox(height: 8),
      ])),
    );
    if (source == null) return null;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, maxWidth: 1280, imageQuality: 85);
      return picked == null ? null : File(picked.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossible d\'accéder à l\'image : $e'),
          backgroundColor: AppColors.danger,
        ));
      }
      return null;
    }
  }

  Future<void> _pickAndUploadLogo() async {
    final file = await _pickImage();
    if (file == null) return;
    setState(() => _uploadingLogo = true);
    try {
      await ref.read(proProvider.notifier).uploadAndSetLogo(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Logo mis à jour ✓'), backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _pickAndUploadCover() async {
    final file = await _pickImage();
    if (file == null) return;
    setState(() => _uploadingCover = true);
    try {
      await ref.read(proProvider.notifier).uploadAndSetCover(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Photo de couverture mise à jour ✓'), backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch pour reconstruire au refresh du state après upload réussi
    // (la cover/logo affichée se met à jour avec la nouvelle URL Cloudinary).
    final pro = ref.watch(proProvider).professional;
    return Scaffold(
    backgroundColor: AppColors.darkBg,
    appBar: AppBar(title: const Text('Mes informations'), leading: const BackButton()),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      // ── Photo couverture + logo overlay ───────────────────────────────
      _CoverWithLogo(
        coverUrl:       pro?.coverImageUrl,
        logoUrl:        pro?.logoUrl,
        categoryEmoji:  pro?.categoryEmoji ?? '🏪',
        uploadingCover: _uploadingCover,
        uploadingLogo:  _uploadingLogo,
        onTapCover:     _uploadingCover ? null : _pickAndUploadCover,
        onTapLogo:      _uploadingLogo  ? null : _pickAndUploadLogo,
      ),
      const SizedBox(height: 24),

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

// ── Photo de couverture + logo overlay (tap pour upload) ────────────────────
class _CoverWithLogo extends StatelessWidget {
  final String? coverUrl;
  final String? logoUrl;
  final String  categoryEmoji;
  final bool    uploadingCover;
  final bool    uploadingLogo;
  final VoidCallback? onTapCover;
  final VoidCallback? onTapLogo;

  const _CoverWithLogo({
    this.coverUrl, this.logoUrl, required this.categoryEmoji,
    this.uploadingCover = false, this.uploadingLogo = false,
    this.onTapCover, this.onTapLogo,
  });

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    // ── Cover bandeau (16:9) ───────────────────────────────────────────────
    GestureDetector(
      onTap: onTapCover,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.darkBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (coverUrl != null && coverUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: coverUrl!,
              fit: BoxFit.cover,
              placeholder: (_, __) => const Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => _placeholderCover(),
            )
          else
            _placeholderCover(),
          if (uploadingCover)
            Container(
              color: Colors.black.withOpacity(0.5),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            )
          else
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Couverture',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
            ),
        ]),
      ),
    ),
    // ── Logo rond overlay (en bas à gauche) ────────────────────────────────
    Positioned(
      left: 16, bottom: -20,
      child: GestureDetector(
        onTap: onTapLogo,
        child: Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.darkBg, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(fit: StackFit.expand, children: [
            if (logoUrl != null && logoUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _logoPlaceholder(),
                errorWidget: (_, __, ___) => _logoPlaceholder(),
              )
            else
              _logoPlaceholder(),
            if (uploadingLogo)
              Container(
                color: Colors.black.withOpacity(0.5),
                alignment: Alignment.center,
                child: const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
              )
            else
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle,
                    border: Border.all(color: AppColors.darkBg, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.white),
                ),
              ),
          ]),
        ),
      ),
    ),
  ]);

  Widget _placeholderCover() => Container(
    color: AppColors.darkCard,
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.image_rounded, color: AppColors.darkMuted, size: 32),
      SizedBox(height: 6),
      Text('Toucher pour ajouter une couverture',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _logoPlaceholder() => Container(
    color: AppColors.primary.withOpacity(0.18),
    alignment: Alignment.center,
    child: Text(categoryEmoji, style: const TextStyle(fontSize: 28)),
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
