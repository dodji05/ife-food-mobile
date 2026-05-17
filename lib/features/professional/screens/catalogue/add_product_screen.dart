// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Ajout / édition d'un produit (vue pro)
//
// Workflow :
//   • L'extra de route est un Map<String, dynamic> (sérialisation Product).
//     Si présent → mode édition. Sinon → mode création.
//   • Le formulaire saisit nom FR/EN, description FR, prix, stock optionnel,
//     disponibilité, et photo optionnelle (image_picker).
//   • Sauvegarde en 2 temps :
//       1. POST /products  ou  PATCH /products/:id  (JSON, sans image)
//       2. Si une nouvelle image a été choisie : POST /products/:id/image
//          (multipart). L'upload échoue silencieusement avec snackbar dédié,
//          le produit reste créé/modifié → pas de rollback brutal.
//   • Le multilingue est limité à FR/EN côté UI (les autres langues sont
//     remplies en backend par auto-traduction ou défaut FR si absentes).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  /// Pré-remplissage en mode édition. `null` = création.
  final Map<String, dynamic>? product;
  const AddProductScreen({super.key, this.product});

  @override
  ConsumerState<AddProductScreen> createState() => _State();
}

class _State extends ConsumerState<AddProductScreen> {
  final _nameFr = TextEditingController();
  final _nameEn = TextEditingController();
  final _descFr = TextEditingController();
  final _price  = TextEditingController();
  final _stock  = TextEditingController();

  bool   _available = true;
  bool   _loading   = false;
  /// Fichier image local choisi par l'utilisateur (pas encore uploadé).
  File?  _pickedImage;
  /// URL existante (mode édition) — affichée tant que l'utilisateur n'a pas
  /// choisi une nouvelle photo.
  String? _existingImageUrl;

  bool get _isEdit => widget.product != null;
  bool get _canSave =>
      _nameFr.text.trim().isNotEmpty &&
      _price.text.trim().isNotEmpty &&
      !_loading;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      // Le name/description peuvent venir soit en Map (i18n natif) soit en
      // String (legacy après extraction). On gère les deux.
      final rawName = p['name'];
      final rawDesc = p['description'];
      if (rawName is Map) {
        _nameFr.text = (rawName['fr'] ?? '').toString();
        _nameEn.text = (rawName['en'] ?? '').toString();
      } else if (rawName is String) {
        _nameFr.text = rawName;
      }
      if (rawDesc is Map) {
        _descFr.text = (rawDesc['fr'] ?? '').toString();
      } else if (rawDesc is String) {
        _descFr.text = rawDesc;
      }
      _price.text  = ((p['price'] as num?) ?? 0).toStringAsFixed(0);
      _stock.text  = p['stock'] != null ? '${p['stock']}' : '';
      _available   = p['isAvailable'] as bool? ?? true;
      _existingImageUrl = p['imageUrl'] as String?;
    }
  }

  @override
  void dispose() {
    _nameFr.dispose();
    _nameEn.dispose();
    _descFr.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  // ── Picker image (galerie ou caméra) ─────────────────────────────────────
  Future<void> _pickImage() async {
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
    if (source == null) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1280,        // Limite côté pour <5 Mo après JPEG compress.
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Impossible d\'accéder à l\'image : $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  // ── Save (create or update + image upload) ───────────────────────────────
  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _loading = true);

    // Construction du payload. Le name est multilingue : on remplit FR (requis),
    // EN si fourni (sinon défaut = FR). Le backend complète les autres langues.
    final fr = _nameFr.text.trim();
    final en = _nameEn.text.trim().isEmpty ? fr : _nameEn.text.trim();
    final descFr = _descFr.text.trim();
    final stockVal = int.tryParse(_stock.text.trim());

    final data = <String, dynamic>{
      'name':       {'fr': fr, 'en': en},
      if (descFr.isNotEmpty) 'description': {'fr': descFr, 'en': descFr},
      'price':      double.tryParse(_price.text.trim()) ?? 0,
      'currency':   'XOF',
      'isAvailable': _available,
      if (stockVal != null) 'stock': stockVal,
    };

    try {
      String productId;
      if (_isEdit) {
        productId = widget.product!['id'] as String;
        await ref.read(proProvider.notifier).updateProduct(productId, data);
      } else {
        productId = await ref.read(proProvider.notifier).createProduct(data);
      }

      // Upload image (best-effort : on ne rollback PAS le produit si l'upload
      // échoue. L'utilisateur retentera depuis l'édition).
      if (_pickedImage != null && productId.isNotEmpty) {
        try {
          await ref.read(proProvider.notifier)
              .uploadProductImage(productId, _pickedImage!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Produit enregistré, mais photo non envoyée : '
                  '${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: AppColors.warning,
            ));
          }
        }
      }

      ref.invalidate(productsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit ? 'Produit modifié ✓' : 'Produit ajouté ✓'),
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
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le produit' : 'Nouveau produit'),
        leading: const BackButton(),
      ),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        // ── Photo ──────────────────────────────────────────────────────────
        GestureDetector(
          onTap: _loading ? null : _pickImage,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppColors.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.darkBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildImagePreview(),
          ),
        ),
        const SizedBox(height: 24),

        _Label('Nom du produit (Français) *'),
        const SizedBox(height: 8),
        _TF(_nameFr, 'Ex: Riz sauce graine', onChanged: (_) => setState(() {})),
        const SizedBox(height: 16),

        _Label('Nom du produit (Anglais)'),
        const SizedBox(height: 8),
        _TF(_nameEn, 'Ex: Palm nut rice'),
        const SizedBox(height: 16),

        _Label('Description (optionnelle)'),
        const SizedBox(height: 8),
        _TF(_descFr, 'Décrivez votre produit…', maxLines: 3),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Label('Prix (F CFA) *'),
            const SizedBox(height: 8),
            _TF(_price, '2500',
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {})),
          ])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Label('Stock (optionnel)'),
            const SizedBox(height: 8),
            _TF(_stock, '∞', keyboardType: TextInputType.number),
          ])),
        ]),
        const SizedBox(height: 20),

        // ── Disponibilité ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.darkCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Row(children: [
            const Icon(Icons.inventory_2_rounded, color: AppColors.darkSubtext, size: 20),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Disponible',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
              Text('Le produit est visible et commandable',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
            ])),
            Switch(
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              activeColor: AppColors.primary,
            ),
          ]),
        ),
        const SizedBox(height: 32),

        ElevatedButton(
          onPressed: _canSave ? _save : null,
          child: _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isEdit ? 'Enregistrer les modifications' : 'Ajouter au catalogue'),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Aperçu image (3 états : local choisi / URL existante / placeholder) ──
  Widget _buildImagePreview() {
    if (_pickedImage != null) {
      return Stack(fit: StackFit.expand, children: [
        Image.file(_pickedImage!, fit: BoxFit.cover),
        _imageOverlayHint('Toucher pour changer'),
      ]);
    }
    if (_existingImageUrl != null && _existingImageUrl!.isNotEmpty) {
      return Stack(fit: StackFit.expand, children: [
        CachedNetworkImage(
          imageUrl: _existingImageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          ),
          errorWidget: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_rounded, color: AppColors.darkMuted, size: 36),
          ),
        ),
        _imageOverlayHint('Toucher pour changer'),
      ]);
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
      Icon(Icons.add_photo_alternate_rounded, color: AppColors.darkMuted, size: 36),
      SizedBox(height: 8),
      Text('Ajouter une photo',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
      Text('JPEG, PNG • Max 5 Mo',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkMuted)),
    ]);
  }

  Widget _imageOverlayHint(String text) => Positioned(
    bottom: 0, left: 0, right: 0,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: Colors.black.withOpacity(0.55),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Text(text,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    ),
  );

  Widget _Label(String t) => Text(t,
    style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkSubtext, letterSpacing: 0.3));

  Widget _TF(TextEditingController ctrl, String hint,
      {TextInputType? keyboardType, int? maxLines, void Function(String)? onChanged}) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    maxLines: maxLines ?? 1,
    onChanged: onChanged,
    style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkText),
    decoration: InputDecoration(hintText: hint),
  );
}
