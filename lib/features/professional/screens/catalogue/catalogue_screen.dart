// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Catalogue (vue pro)
// Affiche tous les produits du pro courant, avec actions rapides :
//   • Toggle disponibilité (1 tap, optimistic update)
//   • Édition (push /pro/add-product avec extra: product)
//   • Suppression (confirmation + appel API)
//   • Ajout (FAB → /pro/add-product sans extra)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/product.dart';
import '../../providers/pro_provider.dart';

class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync   = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final commissionRate  = ref.watch(proProvider).professional?.commissionRate;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        title: const Text('Mon catalogue'),
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(productsProvider);
              ref.invalidate(categoriesProvider);
            },
            icon: Icon(Icons.refresh_rounded, color: context.textPrimary),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pro/add-product'),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ajouter',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: Column(children: [
        if (commissionRate != null && commissionRate > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withOpacity(0.10),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'Une commission de ${commissionRate.toStringAsFixed(0)}% sera ajoutée à chaque plat ou menu.',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    fontWeight: FontWeight.w600, color: AppColors.primary),
              )),
            ]),
          ),
        Expanded(child: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => _ErrorState(message: e.toString(), onRetry: () => ref.invalidate(productsProvider)),
        data: (products) {
          if (products.isEmpty) return _EmptyState();
          // Si les catégories n'ont pas chargé, on retombe sur une liste plate
          // pour ne pas bloquer l'affichage des produits.
          final categories = categoriesAsync.maybeWhen(
            data: (list) => list,
            orElse: () => const <ProductCategory>[],
          );
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(productsProvider);
              ref.invalidate(categoriesProvider);
            },
            child: _GroupedCatalogue(products: products, categories: categories),
          );
        },
        )),
      ]),
    );
  }
}

// ── Liste groupée par catégorie (sections expandables) ─────────────────────
class _GroupedCatalogue extends StatefulWidget {
  final List<Product> products;
  final List<ProductCategory> categories;
  const _GroupedCatalogue({required this.products, required this.categories});

  @override
  State<_GroupedCatalogue> createState() => _GroupedCatalogueState();
}

class _GroupedCatalogueState extends State<_GroupedCatalogue> {
  /// Catégories repliées par l'utilisateur. Par défaut, tout est déplié
  /// pour que le pro voie immédiatement l'inventaire.
  final Set<String> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    // Map id catégorie -> [produits]
    final byCategory = <String, List<Product>>{};
    for (final p in widget.products) {
      final key = p.categoryId ?? '__none__';
      byCategory.putIfAbsent(key, () => []).add(p);
    }

    // Ordre d'affichage : catégories existantes (sortOrder), puis 'Sans catégorie'.
    final orderedKeys = <String>[];
    for (final c in widget.categories) {
      if (byCategory.containsKey(c.id)) orderedKeys.add(c.id);
    }
    // Catégories référencées par des produits mais inconnues (orphan).
    for (final k in byCategory.keys) {
      if (k != '__none__' && !orderedKeys.contains(k)) orderedKeys.add(k);
    }
    if (byCategory.containsKey('__none__')) orderedKeys.add('__none__');

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: orderedKeys.length,
      itemBuilder: (_, i) {
        final key  = orderedKeys[i];
        final list = byCategory[key]!;
        final cat  = key == '__none__'
            ? null
            : widget.categories.firstWhere(
                (c) => c.id == key,
                orElse: () => ProductCategory(
                  id: key, professionalId: '', name: {'fr': 'Catégorie inconnue'},
                ),
              );
        final label = cat?.localizedName('fr') ?? 'Sans catégorie';
        final isCollapsed = _collapsed.contains(key);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header de section : nom + nombre + collapse toggle
          GestureDetector(
            onTap: () => setState(() {
              if (isCollapsed) {
                _collapsed.remove(key);
              } else {
                _collapsed.add(key);
              }
            }),
            child: Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 18, bottom: 10),
              child: Row(children: [
                if (cat?.icon != null && cat!.icon!.isNotEmpty) ...[
                  Text(cat.icon!, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w900,
                    color: context.textPrimary, letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${list.length}',
                    style: const TextStyle(
                      fontFamily: 'Nunito', fontSize: 11,
                      fontWeight: FontWeight.w800, color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(
                  isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                  color: context.textSecondary, size: 22,
                ),
              ]),
            ),
          ),
          if (!isCollapsed)
            ...list.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ProductCard(product: p),
            )),
        ]);
      },
    );
  }
}

// ── Carte produit avec actions ───────────────────────────────────────────────
class _ProductCard extends ConsumerStatefulWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  ConsumerState<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends ConsumerState<_ProductCard> {
  bool _toggling = false;

  Future<void> _toggleAvailability() async {
    setState(() => _toggling = true);
    try {
      await ref
          .read(proProvider.notifier)
          .toggleProductAvailability(widget.product.id, widget.product.isAvailable);
      ref.invalidate(productsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        title: Text('Supprimer "${widget.product.localizedName('fr')}" ?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: context.textPrimary, fontSize: 16)),
        content: Text('Cette action est irréversible. Le produit sera retiré de votre catalogue.',
          style: TextStyle(fontFamily: 'Nunito', color: context.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: TextStyle(color: context.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(proProvider.notifier).deleteProduct(widget.product.id);
      ref.invalidate(productsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Produit supprimé'),
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

  void _edit() {
    // L'écran AddProduct reçoit un Map<String, dynamic> (legacy), on lui passe
    // la sérialisation du produit pour pré-remplir le formulaire.
    context.push('/pro/add-product', extra: widget.product.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final unavailable = !p.isAvailable;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Thumbnail ────────────────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 70, height: 70,
            child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: p.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: context.bgColor,
                      child: Icon(Icons.image_rounded, color: context.textMuted, size: 24),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: context.bgColor,
                      child: Icon(Icons.broken_image_rounded, color: context.textMuted, size: 24),
                    ),
                  )
                : Container(
                    color: context.bgColor,
                    child: Icon(Icons.fastfood_rounded, color: context.textMuted, size: 28),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        // ── Infos ───────────────────────────────────────────────────────
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(
              p.localizedName('fr'),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800,
                color: unavailable ? context.textMuted : context.textPrimary,
                decoration: unavailable ? TextDecoration.lineThrough : null,
              ),
            )),
            if (p.isOutOfStock)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: _Badge('Rupture', color: AppColors.danger),
              ),
          ]),
          const SizedBox(height: 4),
          if (p.description != null && p.description!.isNotEmpty)
            Text(
              p.localizedDescription('fr') ?? '',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary, height: 1.3),
            ),
          const SizedBox(height: 6),
          Row(children: [
            Text(p.formattedPrice,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary)),
            if (p.stock != null) ...[
              const SizedBox(width: 10),
              Text('Stock : ${p.stock}',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
            ],
          ]),
        ])),
        const SizedBox(width: 6),
        // ── Actions ─────────────────────────────────────────────────────
        Column(children: [
          SizedBox(
            width: 44, height: 26,
            child: Switch(
              value: p.isAvailable,
              onChanged: _toggling ? null : (_) => _toggleAvailability(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          PopupMenuButton<String>(
            color: context.cardColor,
            icon: Icon(Icons.more_vert_rounded, color: context.textSecondary, size: 20),
            onSelected: (v) {
              if (v == 'edit') _edit();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Builder(builder: (ctx) => Row(children: [
                  Icon(Icons.edit_rounded, size: 16, color: ctx.textPrimary),
                  const SizedBox(width: 8),
                  Text('Modifier', style: TextStyle(fontFamily: 'Nunito', color: ctx.textPrimary)),
                ])),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                  SizedBox(width: 8),
                  Text('Supprimer', style: TextStyle(fontFamily: 'Nunito', color: AppColors.danger)),
                ]),
              ),
            ],
          ),
        ]),
      ]),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.restaurant_menu_rounded, size: 64, color: context.textMuted),
        const SizedBox(height: 16),
        Text('Aucun produit dans votre catalogue',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text(
          'Ajoutez votre premier produit pour commencer à recevoir des commandes.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: () => GoRouter.of(context).push('/pro/add-product'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter mon premier produit'),
        ),
      ]),
    ),
  );
}

// ── Error state ──────────────────────────────────────────────────────────────
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
        Text('Impossible de charger le catalogue',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
        const SizedBox(height: 6),
        Text(message.replaceAll('Exception: ', ''),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12, color: context.textSecondary)),
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

// ── Mini badge réutilisable ─────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, {required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text,
      style: TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w800, color: color)),
  );
}
