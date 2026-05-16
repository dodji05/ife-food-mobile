import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/pro_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? product;
  const AddProductScreen({super.key, this.product});
  @override ConsumerState<AddProductScreen> createState() => _State();
}

class _State extends ConsumerState<AddProductScreen> {
  final _nameFr = TextEditingController();
  final _nameEn = TextEditingController();
  final _descFr = TextEditingController();
  final _price  = TextEditingController();
  bool _available = true;
  bool _loading = false;
  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final p = widget.product!;
      final name = p['name'] as Map? ?? {};
      final desc = p['description'] as Map? ?? {};
      _nameFr.text = name['fr'] ?? '';
      _nameEn.text = name['en'] ?? '';
      _descFr.text = desc['fr'] ?? '';
      _price.text  = (p['price'] ?? 0).toStringAsFixed(0);
      _available   = p['isAvailable'] ?? true;
    }
  }

  @override
  void dispose() { _nameFr.dispose(); _nameEn.dispose(); _descFr.dispose(); _price.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_nameFr.text.isEmpty || _price.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      final data = {
        'name': {'fr': _nameFr.text.trim(), 'en': _nameEn.text.trim().isEmpty ? _nameFr.text.trim() : _nameEn.text.trim(), 'es': _nameFr.text.trim(), 'de': _nameFr.text.trim(), 'ru': _nameFr.text.trim(), 'ar': _nameFr.text.trim(), 'zh': _nameFr.text.trim()},
        if (_descFr.text.isNotEmpty) 'description': {'fr': _descFr.text.trim(), 'en': _descFr.text.trim()},
        'price': double.tryParse(_price.text) ?? 0,
        'currency': 'XOF',
        'isAvailable': _available,
      };

      if (_isEdit) {
        await ApiClient.instance.patch('/products/${widget.product!['id']}', data: data);
      } else {
        await ApiClient.instance.post('/products', data: data);
      }
      ref.invalidate(productsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.danger));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.darkBg,
    appBar: AppBar(title: Text(_isEdit ? 'Modifier le produit' : 'Nouveau produit'), leading: const BackButton()),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      // Image placeholder
      GestureDetector(
        onTap: () {}, // Would use image_picker
        child: Container(
          height: 160, decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.darkBorder, style: BorderStyle.solid)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_photo_alternate_rounded, color: AppColors.darkMuted, size: 36),
            const SizedBox(height: 8),
            const Text('Ajouter une photo', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.darkSubtext, fontWeight: FontWeight.w600)),
            const Text('JPEG, PNG • Max 5 Mo', style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkMuted)),
          ]),
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

      _Label('Prix (F CFA) *'),
      const SizedBox(height: 8),
      _TF(_price, '2500', keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
      const SizedBox(height: 20),

      // Availability toggle
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.darkCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.darkBorder)),
        child: Row(children: [
          const Icon(Icons.inventory_2_rounded, color: AppColors.darkSubtext, size: 20),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Disponible', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            Text('Le produit est visible et commandable', style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
          ])),
          Switch(value: _available, onChanged: (v) => setState(() => _available = v), activeColor: AppColors.primary),
        ]),
      ),
      const SizedBox(height: 32),

      ElevatedButton(
        onPressed: (_nameFr.text.isNotEmpty && _price.text.isNotEmpty && !_loading) ? _save : null,
        child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_isEdit ? 'Enregistrer les modifications' : 'Ajouter au catalogue'),
      ),
      const SizedBox(height: 40),
    ]),
  );

  Widget _Label(String t) => Text(t, style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkSubtext, letterSpacing: 0.3));

  Widget _TF(TextEditingController ctrl, String hint, {TextInputType? keyboardType, int? maxLines, void Function(String)? onChanged}) => TextField(
    controller: ctrl, keyboardType: keyboardType, maxLines: maxLines ?? 1, onChanged: onChanged,
    style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkText),
    decoration: InputDecoration(hintText: hint),
  );
}
