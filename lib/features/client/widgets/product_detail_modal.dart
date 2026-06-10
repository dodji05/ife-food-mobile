// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Bottom sheet fiche produit (client)
//
// Usage :
//   await showProductDetail(context,
//     product: product,
//     professionalId: product.professionalId,
//     proName: 'Nom du restaurant',   // optionnel — pour la boîte de dialogue
//     isProOpen: true,
//   );
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/currency_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_colors.dart';
import '../../../shared/models/product.dart';
import '../providers/cart_provider.dart';
import 'scheduled_delivery_dialog.dart';

Future<void> showProductDetail(
  BuildContext context, {
  required Product product,
  required String professionalId,
  String? proName,
  bool isProOpen = true,
  Map<String, dynamic>? openingHours,
}) {
  final container = ProviderScope.containerOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _ProductDetailSheet(
        product: product,
        professionalId: professionalId,
        proName: proName,
        isProOpen: isProOpen,
        openingHours: openingHours,
      ),
    ),
  );
}

class _ProductDetailSheet extends ConsumerStatefulWidget {
  final Product  product;
  final String   professionalId;
  final String?  proName;
  final bool     isProOpen;
  final Map<String, dynamic>? openingHours;

  const _ProductDetailSheet({
    required this.product,
    required this.professionalId,
    this.proName,
    this.isProOpen = true,
    this.openingHours,
  });

  @override
  ConsumerState<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends ConsumerState<_ProductDetailSheet> {
  int? _selectedVariantIndex;

  Product get product => widget.product;
  List<Map<String, dynamic>> get variants => product.variants;

  double get _displayPrice {
    if (_selectedVariantIndex != null) {
      final v = variants[_selectedVariantIndex!];
      final p = v['price'];
      if (p != null) return (p as num).toDouble();
    }
    return product.price;
  }

  String get _formattedDisplayPrice {
    // Conversion à l'affichage selon la devise du client (estimation).
    return ref.watch(currencyFormatterProvider).format(_displayPrice);
  }

  Future<void> _addToCart() async {
    DateTime? scheduledFor;
    if (!widget.isProOpen) {
      final nextOpening = nextOpeningTime(widget.openingHours);
      final ok = await showScheduledDeliveryDialog(context, nextOpening: nextOpening);
      if (!ok || !mounted) return;
      scheduledFor = nextOpening;
    }

    final notifier = ref.read(cartProvider.notifier);

    // Produit à ajouter (éventuellement avec prix de variante)
    Product productToAdd = product;
    if (_selectedVariantIndex != null) {
      final v = variants[_selectedVariantIndex!];
      final variantName = v['name']?.toString() ?? '';
      final variantPrice = (v['price'] as num?)?.toDouble() ?? product.price;
      productToAdd = product.copyWith(
        name: variantName.isNotEmpty ? '${product.name} ($variantName)' : null,
        price: variantPrice,
      );
    }

    if (notifier.canAddFrom(widget.professionalId)) {
      notifier.addItem(productToAdd, widget.professionalId);
      if (scheduledFor != null) notifier.setScheduledDelivery(scheduledFor);
      if (mounted) Navigator.pop(context);
      return;
    }

    // Conflit restaurant
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer de restaurant ?'),
        content: Text(
          'Votre panier contient des articles d\'un autre établissement. '
          'Voulez-vous le vider pour commander'
          '${widget.proName != null ? ' chez "${widget.proName}"' : ''} ?',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider et continuer',
              style: TextStyle(color: AppColors.primary,
                  fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    notifier.clearCart();
    notifier.addItem(productToAdd, widget.professionalId);
    if (scheduledFor != null) notifier.setScheduledDelivery(scheduledFor);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.9),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // ── Contenu scrollable ────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottom + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image produit
                  _ProductImage(product: product),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom + badge état (rupture / indisponible)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                product.localizedName('fr'),
                                style: TextStyle(
                                  fontFamily: 'Nunito', fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: context.textPrimary),
                              ),
                            ),
                            if (product.isOutOfStock)
                              Container(
                                margin: const EdgeInsets.only(left: 8, top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppColors.warning.withOpacity(0.4))),
                                child: const Text('Rupture de stock',
                                  style: TextStyle(
                                    fontFamily: 'Nunito', fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning)),
                              )
                            else if (!product.isAvailable)
                              Container(
                                margin: const EdgeInsets.only(left: 8, top: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.danger.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                                child: const Text('Indisponible',
                                  style: TextStyle(
                                    fontFamily: 'Nunito', fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.danger)),
                              ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // Prix
                        Text(
                          _formattedDisplayPrice,
                          style: const TextStyle(
                            fontFamily: 'Nunito', fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary),
                        ),

                        // Temps de préparation
                        if (product.preparationTimeMin != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.timer_outlined,
                                size: 14, color: context.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${product.preparationTimeMin} min de préparation',
                              style: TextStyle(
                                fontFamily: 'Nunito', fontSize: 12,
                                color: context.textMuted)),
                          ]),
                        ],

                        // Description
                        if (product.localizedDescription('fr') != null &&
                            product.localizedDescription('fr')!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            product.localizedDescription('fr')!,
                            style: TextStyle(
                              fontFamily: 'Nunito', fontSize: 14,
                              color: context.textMuted, height: 1.5),
                          ),
                        ],

                        // Variantes
                        if (variants.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Choisir une taille',
                            style: TextStyle(
                              fontFamily: 'Nunito', fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(variants.length, (i) {
                              final v = variants[i];
                              final name  = v['name']?.toString() ?? '';
                              final price = (v['price'] as num?)?.toDouble();
                              final sel   = i == _selectedVariantIndex;
                              return GestureDetector(
                                onTap: () => setState(() =>
                                    _selectedVariantIndex = sel ? null : i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.primary
                                        : context.bgColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.primary
                                          : context.borderColor),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(name,
                                        style: TextStyle(
                                          fontFamily: 'Nunito',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: sel
                                              ? Colors.white
                                              : context.textPrimary)),
                                      if (price != null)
                                        Text(
                                          '${price.toStringAsFixed(0)} F',
                                          style: TextStyle(
                                            fontFamily: 'Nunito',
                                            fontSize: 11,
                                            color: sel
                                                ? Colors.white.withOpacity(0.85)
                                                : context.textMuted)),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Bouton Ajouter au panier
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (product.isAvailable && !product.isOutOfStock)
                                ? _addToCart : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: product.isOutOfStock
                                  ? AppColors.warning.withOpacity(0.15)
                                  : context.textMuted.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              product.isOutOfStock
                                  ? '⚠️ Rupture de stock'
                                  : !product.isAvailable
                                      ? 'Produit indisponible'
                                      : 'Ajouter au panier — $_formattedDisplayPrice',
                              style: TextStyle(
                                fontFamily: 'Nunito', fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: product.isOutOfStock
                                    ? AppColors.warning
                                    : Colors.white),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Lien vers le restaurant
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.push(
                                  '/restaurant/${widget.professionalId}');
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Voir le restaurant',
                                  style: TextStyle(
                                    fontFamily: 'Nunito', fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                                SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductImage extends StatelessWidget {
  final Product product;
  const _ProductImage({required this.product});

  @override
  Widget build(BuildContext context) {
    const h = 220.0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      child: product.imageUrl != null && product.imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: product.imageUrl!,
              height: h,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _Placeholder(product: product))
          : _Placeholder(product: product),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final Product product;
  const _Placeholder({required this.product});

  @override
  Widget build(BuildContext context) => Container(
    height: 220,
    width: double.infinity,
    color: AppColors.primary.withOpacity(0.08),
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🍽️', style: TextStyle(fontSize: 64)),
        const SizedBox(height: 8),
        Text(product.localizedName('fr'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
      ]),
    ),
  );
}
