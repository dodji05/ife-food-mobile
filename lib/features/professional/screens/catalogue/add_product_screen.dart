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
import '../../../../shared/models/product.dart';
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
  bool   _isMenu    = false;
  bool   _loading   = false;
  /// Fichier image local choisi par l'utilisateur (pas encore uploadé).
  File?  _pickedImage;
  /// URL existante (mode édition) — affichée tant que l'utilisateur n'a pas
  /// choisi une nouvelle photo.
  String? _existingImageUrl;
  /// Catégorie sélectionnée (id). `null` = sans catégorie (groupe par défaut
  /// dans le catalogue côté pro).
  String? _categoryId;

  // ── Variantes (taille / portion) ─────────────────────────────────────────
  final List<TextEditingController> _variantNameCtrls  = [];
  final List<TextEditingController> _variantPriceCtrls = [];

  // ── Options / extras ─────────────────────────────────────────────────────
  final List<TextEditingController> _optionNameCtrls  = [];
  final List<TextEditingController> _optionPriceCtrls = [];
  final List<bool> _optionRequired = [];

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
      _isMenu      = p['isMenu'] as bool? ?? false;
      _existingImageUrl = p['imageUrl'] as String?;
      // categoryId peut venir aplati OU dans la relation 'category' jointe.
      final rawCat = p['category'];
      if (rawCat is Map) {
        _categoryId = rawCat['id'] as String?;
      } else {
        _categoryId = p['categoryId'] as String?;
      }
      // Variantes
      final rawVariants = p['variants'];
      if (rawVariants is List) {
        for (final v in rawVariants) {
          if (v is Map) {
            _variantNameCtrls.add(TextEditingController(text: (v['name'] ?? '').toString()));
            _variantPriceCtrls.add(TextEditingController(text: '${v['price'] ?? 0}'));
          }
        }
      }
      // Options / extras
      final rawOptions = p['options'];
      if (rawOptions is List) {
        for (final o in rawOptions) {
          if (o is Map) {
            _optionNameCtrls.add(TextEditingController(text: (o['name'] ?? '').toString()));
            _optionPriceCtrls.add(TextEditingController(text: '${o['price'] ?? 0}'));
            _optionRequired.add(o['required'] as bool? ?? false);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameFr.dispose();
    _nameEn.dispose();
    _descFr.dispose();
    _price.dispose();
    _stock.dispose();
    for (final c in _variantNameCtrls)  { c.dispose(); }
    for (final c in _variantPriceCtrls) { c.dispose(); }
    for (final c in _optionNameCtrls)   { c.dispose(); }
    for (final c in _optionPriceCtrls)  { c.dispose(); }
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

    // Construction des variantes à partir des controllers
    final variants = <Map<String, dynamic>>[];
    for (var i = 0; i < _variantNameCtrls.length; i++) {
      final name = _variantNameCtrls[i].text.trim();
      if (name.isNotEmpty) {
        variants.add({
          'name':  name,
          'price': double.tryParse(_variantPriceCtrls[i].text.trim()) ?? 0,
        });
      }
    }
    // Construction des options / extras
    final options = <Map<String, dynamic>>[];
    for (var i = 0; i < _optionNameCtrls.length; i++) {
      final name = _optionNameCtrls[i].text.trim();
      if (name.isNotEmpty) {
        options.add({
          'name':     name,
          'price':    double.tryParse(_optionPriceCtrls[i].text.trim()) ?? 0,
          'required': _optionRequired[i],
        });
      }
    }

    final data = <String, dynamic>{
      'name':       {'fr': fr, 'en': en},
      if (descFr.isNotEmpty) 'description': {'fr': descFr, 'en': descFr},
      'price':      double.tryParse(_price.text.trim()) ?? 0,
      'currency':   'XOF',
      'isAvailable': _available,
      'isMenu':     _isMenu,
      if (stockVal != null) 'stock': stockVal,
      if (_categoryId != null) 'categoryId': _categoryId,
      if (variants.isNotEmpty) 'variants': variants,
      if (options.isNotEmpty)  'options':  options,
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
      // Invalidate aussi le provider catégories : si une catégorie a été
      // créée à la volée, la liste catalogue groupée doit la refléter.
      ref.invalidate(categoriesProvider);
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
      // ── Bouton save FIXÉ en bas (toujours visible peu importe le scroll
      //    ou le clavier). Avant : dans le ListView → invisible si formulaire
      //    long ou clavier ouvert (rapport utilisateur).
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
                      _isEdit ? 'Enregistrer les modifications' : 'Ajouter au catalogue',
                      style: const TextStyle(
                        fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
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

        _Label('Catégorie (optionnelle)'),
        const SizedBox(height: 8),
        _CategoryPicker(
          selectedId: _categoryId,
          onChanged: (id) => setState(() => _categoryId = id),
        ),
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
        _ToggleRow(
          icon: Icons.inventory_2_rounded,
          title: 'Disponible',
          subtitle: 'Le produit est visible et commandable',
          value: _available,
          onChanged: (v) => setState(() => _available = v),
        ),
        const SizedBox(height: 12),

        // ── Type : plat ou menu ────────────────────────────────────────────
        _ToggleRow(
          icon: Icons.restaurant_menu_rounded,
          title: 'Menu',
          subtitle: 'Cocher si c\'est un menu (plat complet avec accompagnements)',
          value: _isMenu,
          onChanged: (v) => setState(() => _isMenu = v),
        ),
        const SizedBox(height: 20),

        // ── Bannière commission ────────────────────────────────────────────
        Consumer(builder: (context, cRef, _) {
          final rate = cRef.watch(proProvider).professional?.commissionRate;
          if (rate == null || rate <= 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'Une commission de ${rate.toStringAsFixed(0)}% sera ajoutée à ce produit.',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      fontWeight: FontWeight.w600, color: AppColors.primary),
                )),
              ]),
            ),
          );
        }),

        // ── Variantes ─────────────────────────────────────────────────────
        _SectionTitle(
          'Variantes (optionnel)',
          'Ex: Petit, Normal, Grand — des prix différents pour le même plat',
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _variantNameCtrls.length; i++)
          _VariantOptionRow(
            nameCtrl: _variantNameCtrls[i],
            priceCtrl: _variantPriceCtrls[i],
            nameHint: 'Ex: Grand',
            priceHint: '3500',
            onRemove: () => _removeVariant(i),
          ),
        _AddRowButton('Ajouter une variante', _addVariant),
        const SizedBox(height: 20),

        // ── Options / Extras ───────────────────────────────────────────────
        _SectionTitle(
          'Options / Extras (optionnel)',
          'Ex: Sauce supplémentaire, Sans oignon — suppléments à la commande',
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _optionNameCtrls.length; i++)
          _VariantOptionRow(
            nameCtrl: _optionNameCtrls[i],
            priceCtrl: _optionPriceCtrls[i],
            nameHint: 'Ex: Sauce pimentée',
            priceHint: '0',
            required: _optionRequired[i],
            onRequiredChanged: (v) => setState(() => _optionRequired[i] = v),
            onRemove: () => _removeOption(i),
          ),
        _AddRowButton('Ajouter une option', _addOption),
        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Gestion variantes ─────────────────────────────────────────────────────
  void _addVariant() => setState(() {
    _variantNameCtrls.add(TextEditingController());
    _variantPriceCtrls.add(TextEditingController());
  });

  void _removeVariant(int i) => setState(() {
    _variantNameCtrls[i].dispose();
    _variantPriceCtrls[i].dispose();
    _variantNameCtrls.removeAt(i);
    _variantPriceCtrls.removeAt(i);
  });

  // ── Gestion options ───────────────────────────────────────────────────────
  void _addOption() => setState(() {
    _optionNameCtrls.add(TextEditingController());
    _optionPriceCtrls.add(TextEditingController());
    _optionRequired.add(false);
  });

  void _removeOption(int i) => setState(() {
    _optionNameCtrls[i].dispose();
    _optionPriceCtrls[i].dispose();
    _optionNameCtrls.removeAt(i);
    _optionPriceCtrls.removeAt(i);
    _optionRequired.removeAt(i);
  });

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

// ── Toggle row (disponibilité, isMenu) ────────────────────────────────────
class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon, required this.title, required this.subtitle,
    required this.value, required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Row(children: [
      Icon(icon, color: AppColors.darkSubtext, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
        Text(subtitle, style: const TextStyle(
          fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
    ]),
  );
}

// ── En-tête de section (variantes / options) ──────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle(this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(
      fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
      color: AppColors.darkSubtext, letterSpacing: 0.3)),
    const SizedBox(height: 2),
    Text(subtitle, style: const TextStyle(
      fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkMuted)),
  ]);
}

// ── Ligne variante ou option ──────────────────────────────────────────────
class _VariantOptionRow extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  final String nameHint;
  final String priceHint;
  final bool? required;
  final ValueChanged<bool>? onRequiredChanged;
  final VoidCallback onRemove;
  const _VariantOptionRow({
    required this.nameCtrl, required this.priceCtrl,
    required this.nameHint, required this.priceHint,
    this.required, this.onRequiredChanged,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Expanded(flex: 3, child: TextField(
        controller: nameCtrl,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkText),
        decoration: InputDecoration(
          hintText: nameHint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      )),
      const SizedBox(width: 8),
      Expanded(flex: 2, child: TextField(
        controller: priceCtrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkText),
        decoration: InputDecoration(
          hintText: priceHint,
          suffixText: 'F',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      )),
      if (required != null && onRequiredChanged != null) ...[
        const SizedBox(width: 4),
        Tooltip(
          message: 'Obligatoire',
          child: Checkbox(
            value: required,
            onChanged: (v) => onRequiredChanged!(v ?? false),
            activeColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
      IconButton(
        onPressed: onRemove,
        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20, color: AppColors.danger),
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
      ),
    ]),
  );
}

// ── Bouton "Ajouter une ligne" ────────────────────────────────────────────
class _AddRowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddRowButton(this.label, this.onTap);
  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
    label: Text(label,
      style: const TextStyle(
        fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
    style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
  );
}

// ── Sélecteur de catégorie (dropdown + bouton 'Nouvelle catégorie') ────────
class _CategoryPicker extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  const _CategoryPicker({required this.selectedId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCats = ref.watch(categoriesProvider);
    return asyncCats.when(
      loading: () => Container(
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.darkCard, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.darkBorder),
        ),
        alignment: Alignment.center,
        child: const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
      ),
      error: (_, __) => _newOnlyButton(context, ref),
      data: (cats) => Row(children: [
        Expanded(child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkCard, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.darkBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: cats.any((c) => c.id == selectedId) ? selectedId : null,
              isExpanded: true,
              hint: const Text('Sans catégorie',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext)),
              dropdownColor: AppColors.darkCard,
              icon: const Icon(Icons.expand_more_rounded, color: AppColors.darkSubtext),
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w600, color: AppColors.darkText),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sans catégorie',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext)),
                ),
                ...cats.map((c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Row(children: [
                    if (c.icon != null && c.icon!.isNotEmpty) ...[
                      Text(c.icon!, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(c.localizedName('fr'),
                      maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                )),
              ],
              onChanged: onChanged,
            ),
          ),
        )),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Nouvelle catégorie',
          onPressed: () => _showCreateCategoryDialog(context, ref),
          icon: Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _newOnlyButton(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
    onPressed: () => _showCreateCategoryDialog(context, ref),
    icon: const Icon(Icons.add_rounded, size: 16),
    label: const Text('Nouvelle catégorie'),
  );

  Future<void> _showCreateCategoryDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final iconCtrl = TextEditingController();
    final created = await showDialog<String?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) {
          bool busy = false;
          return AlertDialog(
            backgroundColor: AppColors.darkCard,
            title: const Text('Nouvelle catégorie',
              style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, color: AppColors.darkText, fontSize: 16)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Ex: Entrées, Boissons…'),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.darkText),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: 'Emoji (optionnel) — ex: 🥗',
                  counterText: '',
                ),
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, color: AppColors.darkText),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: AppColors.darkSubtext)),
              ),
              ElevatedButton(
                onPressed: busy ? null : () async {
                  final n = nameCtrl.text.trim();
                  if (n.isEmpty) return;
                  setState(() => busy = true);
                  try {
                    final id = await ref.read(proProvider.notifier).createCategory(
                      {'fr': n, 'en': n},
                      icon: iconCtrl.text.trim().isEmpty ? null : iconCtrl.text.trim(),
                    );
                    ref.invalidate(categoriesProvider);
                    if (ctx.mounted) Navigator.pop(ctx, id);
                  } catch (e) {
                    setState(() => busy = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: AppColors.danger,
                      ));
                    }
                  }
                },
                child: busy
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Créer'),
              ),
            ],
          );
        },
      ),
    );
    if (created != null && created.isNotEmpty) onChanged(created);
  }
}
