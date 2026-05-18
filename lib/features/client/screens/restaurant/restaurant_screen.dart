import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/product.dart';
import '../../providers/cart_provider.dart';

final restaurantDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ApiClient.instance.get('/professionals/$id');
  return res['data'];
});

class RestaurantScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  const RestaurantScreen({super.key, required this.restaurantId});
  @override ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedCategoryId = '';

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(restaurantDetailProvider(widget.restaurantId));
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (json) {
          final pro = Professional.fromJson(json);
          final categories = (json['products'] as List? ?? []);
          final products = categories.map((p) => Product.fromJson(p)).toList();

          // Group by category
          final grouped = <String, List<Product>>{};
          for (final p in products) {
            final cat = p.categoryId ?? 'other';
            grouped.putIfAbsent(cat, () => []).add(p);
          }

          return CustomScrollView(
            slivers: [
              // Cover + Back
              SliverAppBar(
                expandedHeight: 220, pinned: true, stretch: true,
                backgroundColor: AppColors.primary,
                leading: GestureDetector(onTap: () => context.pop(),
                  child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_rounded, color: AppColors.nearBlack))),
                actions: [
                  Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: IconButton(icon: const Icon(Icons.share_rounded, color: AppColors.nearBlack), onPressed: () {})),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: pro.coverImageUrl != null
                    ? ColorFiltered(
                        colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.3), BlendMode.darken),
                        child: CachedNetworkImage(imageUrl: pro.coverImageUrl!, fit: BoxFit.cover))
                    : Container(color: AppColors.primary.withOpacity(0.8),
                        child: Center(child: Text(pro.categoryEmoji, style: const TextStyle(fontSize: 72)))),
                ),
              ),

              // Info section
              SliverToBoxAdapter(child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(pro.businessName, style: const TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.nearBlack))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: pro.isOpen ? AppColors.success.withOpacity(0.12) : AppColors.grey.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(pro.isOpen ? '● Ouvert' : '● Fermé',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: pro.isOpen ? AppColors.success : AppColors.grey)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    RatingBarIndicator(rating: pro.avgRating ?? 0, itemBuilder: (_, __) => const Icon(Icons.star_rounded, color: AppColors.yellow), itemSize: 18, itemCount: 5),
                    const SizedBox(width: 6),
                    Text('${(pro.avgRating ?? 0).toStringAsFixed(1)} (${pro.reviewCount ?? 0} avis)',
                      style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _InfoPill(icon: Icons.access_time_rounded, label: '${pro.estimatedDeliveryMin ?? 25}-${(pro.estimatedDeliveryMin ?? 25) + 15} min'),
                    const SizedBox(width: 8),
                    _InfoPill(icon: Icons.delivery_dining_rounded, label: (pro.deliveryFee ?? 0) == 0 ? 'Gratuit' : '${(pro.deliveryFee ?? 0).toStringAsFixed(0)} F'),
                    const SizedBox(width: 8),
                    _InfoPill(icon: Icons.location_on_rounded, label: pro.distance != null ? '${pro.distance!.toStringAsFixed(1)} km' : (pro.city ?? '')),
                  ]),
                  if (pro.description != null) ...[
                    const SizedBox(height: 12),
                    Text(pro.description!, style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey, height: 1.5)),
                  ],
                ]),
              )),

              // Divider
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Products
              ...grouped.entries.map((entry) => SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Text('Produits', style: const TextStyle(fontFamily: 'Nunito', fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
                  ),
                  ...entry.value.map((product) => _ProductItem(product: product, professionalId: pro.id, proName: pro.businessName)),
                ]),
              )).toList(),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon; final String label;
  const _InfoPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkGrey)),
    ]),
  );
}

class _ProductItem extends ConsumerWidget {
  final Product product; final String professionalId; final String proName;
  const _ProductItem({required this.product, required this.professionalId, required this.proName});

  /// Ajoute l'item au panier en gérant le cas multi-pro :
  /// - Si le panier contient déjà des items d'un AUTRE pro -> dialog confirm
  ///   'Vider le panier et passer commande chez X ?'
  /// - Si confirmé : clearCart() puis addItem()
  /// - Sinon (panier vide ou même pro) : addItem() direct
  /// Avant ce fix : addItem() refusait silencieusement (cart_provider:25-29)
  /// -> l'utilisateur ne comprenait pas pourquoi le bouton 'rien faisait'.
  Future<void> _addWithMultiProGuard(BuildContext context, WidgetRef ref) async {
    final cart = ref.read(cartProvider);
    final notifier = ref.read(cartProvider.notifier);

    if (cart.canAddFrom(professionalId)) {
      notifier.addItem(product, professionalId);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer de restaurant ?'),
        content: Text(
          'Votre panier contient des articles d\'un autre établissement. '
          'Voulez-vous le vider pour commander chez "$proName" ?',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vider et continuer',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    notifier.clearCart();
    // Après clearCart, professionalId est null -> addItem accepte
    notifier.addItem(product, professionalId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Panier vidé. ${product.localizedName('fr')} ajouté.'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final cartItem = cart.items.where((i) => i.product.id == product.id).firstOrNull;
    final qty = cartItem?.quantity ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
      child: Row(children: [
        // Image
        ClipRRect(
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(13)),
          child: product.imageUrl != null
            ? CachedNetworkImage(imageUrl: product.imageUrl!, width: 96, height: 96, fit: BoxFit.cover)
            : Container(width: 96, height: 96, color: AppColors.offWhite,
                child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36)))),
        ),
        // Info
        Expanded(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.localizedName('fr'), style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
            if (product.localizedDescription('fr') != null) ...[
              const SizedBox(height: 2),
              Text(product.localizedDescription('fr')!, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey, height: 1.4)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              Text('${product.price.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const Spacer(),
              if (qty == 0)
                GestureDetector(
                  onTap: () => _addWithMultiProGuard(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  ),
                )
              else
                Row(children: [
                  GestureDetector(onTap: () => ref.read(cartProvider.notifier).updateQuantity(product.id, qty - 1),
                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.lightGrey, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.remove_rounded, size: 16, color: AppColors.nearBlack))),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text('$qty', style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 15))),
                  GestureDetector(onTap: () => _addWithMultiProGuard(context, ref),
                    child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.add_rounded, size: 16, color: Colors.white))),
                ]),
            ]),
          ]),
        )),
      ]),
    );
  }
}
