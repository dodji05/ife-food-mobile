// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Gestion des catégories (pro)
//
// CRUD complet sur ProductCategory :
//   • Liste réordonnable (drag handle, le sortOrder est patché en bulk)
//   • Tap sur une carte → dialog rename + edit icon
//   • Swipe gauche / icon corbeille → confirmation puis DELETE
//     (les produits qui référençaient cette catégorie sont décatégorisés
//      côté backend, pas supprimés — info affichée dans la confirmation)
//   • FAB 'Nouvelle catégorie' (réutilise createCategory + dialog inline)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/product.dart';
import '../../providers/pro_provider.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});
  @override
  ConsumerState<ManageCategoriesScreen> createState() => _State();
}

class _State extends ConsumerState<ManageCategoriesScreen> {
  /// Copie locale de la liste pour permettre le drag-reorder sans attendre
  /// l'API. Synchronisée avec le provider à chaque rebuild.
  List<ProductCategory>? _local;
  bool _dirty = false;
  bool _savingOrder = false;

  @override
  Widget build(BuildContext context) {
    final asyncCats = ref.watch(categoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Gérer les catégories'),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _savingOrder ? null : _saveOrder,
              child: _savingOrder
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : const Text('Enregistrer l\'ordre',
                      style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.primary)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nouvelle catégorie',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: asyncCats.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(message: e.toString(), onRetry: () => ref.invalidate(categoriesProvider)),
        data: (cats) {
          // Resynchronise la copie locale uniquement quand l'utilisateur n'a
          // pas de changement non-sauvé en cours (sinon on perdrait son drag).
          if (!_dirty) _local = List.of(cats);
          final list = _local ?? cats;

          if (list.isEmpty) return const _EmptyState();

          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: list.length,
            onReorder: (oldIdx, newIdx) {
              setState(() {
                if (newIdx > oldIdx) newIdx -= 1;
                final item = list.removeAt(oldIdx);
                list.insert(newIdx, item);
                _dirty = true;
              });
            },
            itemBuilder: (_, i) => _CategoryTile(
              key: ValueKey(list[i].id),
              category: list[i],
              onRename: () => _showRenameDialog(list[i]),
              onDelete: () => _confirmDelete(list[i]),
            ),
          );
        },
      ),
    );
  }

  // ── Save reorder via bulk PATCH ───────────────────────────────────────────
  Future<void> _saveOrder() async {
    if (_local == null) return;
    setState(() => _savingOrder = true);
    try {
      final items = <Map<String, dynamic>>[
        for (var i = 0; i < _local!.length; i++)
          {'id': _local![i].id, 'sortOrder': i},
      ];
      await ref.read(proProvider.notifier).reorderCategories(items);
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider); // le catalogue reflète le nouvel ordre
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _savingOrder = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ordre enregistré ✓'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  // ── Create dialog ─────────────────────────────────────────────────────────
  Future<void> _showCreateDialog() async {
    final result = await _editCategoryDialog(
      title: 'Nouvelle catégorie',
      initialName: '',
      initialIcon: '',
      onSubmit: (name, icon) async {
        await ref.read(proProvider.notifier).createCategory(
          {'fr': name, 'en': name},
          icon: icon.isEmpty ? null : icon,
        );
      },
    );
    if (result == true) ref.invalidate(categoriesProvider);
  }

  // ── Rename / edit icon dialog ─────────────────────────────────────────────
  Future<void> _showRenameDialog(ProductCategory cat) async {
    final result = await _editCategoryDialog(
      title: 'Modifier la catégorie',
      initialName: cat.localizedName('fr'),
      initialIcon: cat.icon ?? '',
      onSubmit: (name, icon) async {
        await ref.read(proProvider.notifier).updateCategory(cat.id, {
          'name': {'fr': name, 'en': name},
          'icon': icon, // peut être '' pour clear
        });
      },
    );
    if (result == true) {
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider); // le label des sections catalogue change
    }
  }

  /// Generic dialog : retourne `true` si succès, `null/false` si annulé.
  Future<bool?> _editCategoryDialog({
    required String title,
    required String initialName,
    required String initialIcon,
    required Future<void> Function(String name, String icon) onSubmit,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final iconCtrl = TextEditingController(text: initialIcon);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        bool busy = false;
        return AlertDialog(
          backgroundColor: AppColors.darkCard,
          title: Text(title,
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w900, color: AppColors.darkText, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Nom de la catégorie'),
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
              onPressed: busy ? null : () => Navigator.pop(ctx, false),
              child: const Text('Annuler', style: TextStyle(color: AppColors.darkSubtext)),
            ),
            ElevatedButton(
              onPressed: busy ? null : () async {
                final n = nameCtrl.text.trim();
                if (n.isEmpty) return;
                setS(() => busy = true);
                try {
                  await onSubmit(n, iconCtrl.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setS(() => busy = false);
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
                  : const Text('Enregistrer'),
            ),
          ],
        );
      }),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────────────────
  Future<void> _confirmDelete(ProductCategory cat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: Text('Supprimer "${cat.localizedName('fr')}" ?',
          style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.darkText, fontSize: 16)),
        content: const Text(
          'Les produits dans cette catégorie ne seront PAS supprimés, '
          'ils apparaîtront sous "Sans catégorie" dans le catalogue.',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: AppColors.darkSubtext)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(proProvider.notifier).deleteCategory(cat.id);
      ref.invalidate(categoriesProvider);
      ref.invalidate(productsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Catégorie "${cat.localizedName('fr')}" supprimée'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    }
  }
}

// ── Tile catégorie réordonnable ─────────────────────────────────────────────
class _CategoryTile extends StatelessWidget {
  final ProductCategory category;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _CategoryTile({
    super.key,
    required this.category,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.darkCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.darkBorder),
    ),
    child: Row(children: [
      // Icône drag : indicateur visuel uniquement — ReorderableListView gère
      // le drag par long-press n'importe où sur la tile (par défaut Flutter).
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6),
        child: Icon(Icons.drag_indicator_rounded, color: AppColors.darkMuted, size: 22),
      ),
      const SizedBox(width: 6),
      Container(
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          category.icon == null || category.icon!.isEmpty ? '📁' : category.icon!,
          style: const TextStyle(fontSize: 18),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(category.localizedName('fr'),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.darkText)),
        Text('Ordre : ${category.sortOrder}',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 11, color: AppColors.darkSubtext)),
      ])),
      IconButton(
        onPressed: onRename,
        tooltip: 'Modifier',
        icon: const Icon(Icons.edit_outlined, color: AppColors.darkSubtext, size: 20),
      ),
      IconButton(
        onPressed: onDelete,
        tooltip: 'Supprimer',
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
      ),
    ]),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [
        Icon(Icons.folder_outlined, size: 64, color: AppColors.darkMuted),
        SizedBox(height: 16),
        Text('Aucune catégorie',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.darkText)),
        SizedBox(height: 6),
        Text(
          'Créez des catégories pour grouper vos produits dans le catalogue.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.darkSubtext, height: 1.5),
        ),
      ]),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.danger),
        const SizedBox(height: 12),
        Text(message.replaceAll('Exception: ', ''),
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkSubtext)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ]),
    ),
  );
}
