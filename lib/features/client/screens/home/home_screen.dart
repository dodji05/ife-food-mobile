import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/product.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notifications_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final nearbyProfessionalsProvider =
    FutureProvider.autoDispose.family<List<Professional>, int>((ref, radius) async {
  final res = await ApiClient.instance.get('/geo/nearby', params: {
    'lat': AppConstants.defaultLat,
    'lng': AppConstants.defaultLng,
    'radius': radius == 0 ? 200 : radius,
  });
  final list = res['data'] as List? ?? [];
  return list.map((e) => Professional.fromJson(e as Map<String, dynamic>)).toList();
});

final popularProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final res = await ApiClient.instance.get('/products/search', params: {
    'q': '',
    'lat': AppConstants.defaultLat,
    'lng': AppConstants.defaultLng,
  });
  final raw = res['data'];
  final list = raw is List ? raw : (raw as Map<String, dynamic>?)?['items'] as List? ?? [];
  return list
      .take(16)
      .map((e) => Product.fromJson(e as Map<String, dynamic>))
      .toList();
});

final bannersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/config/banners');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

// ── Écran principal ───────────────────────────────────────────────────────────

String _avatarInitial(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  return name.trim().substring(0, 1).toUpperCase();
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'all';
  int    _selectedRadius   = 0;

  static const _radiusOptions = [
    (label: 'Tout',  km: 0),
    (label: '5 km',  km: 5),
    (label: '10 km', km: 10),
    (label: '20 km', km: 20),
  ];

  final _categories = [
    {'id': 'all',         'label': 'Tout',     'emoji': '🌟'},
    {'id': 'RESTAURANT',  'label': 'Restos',   'emoji': '🍽️'},
    {'id': 'GROCERY',     'label': 'Épicerie', 'emoji': '🛒'},
    {'id': 'SUPERMARKET', 'label': 'Super',    'emoji': '🏪'},
    {'id': 'BAKERY',      'label': 'Boulang.', 'emoji': '🥖'},
    {'id': 'PHARMACY',    'label': 'Pharma',   'emoji': '💊'},
  ];

  @override
  Widget build(BuildContext context) {
    final authState   = ref.watch(authProvider);
    final user        = authState.user;
    final professionals = ref.watch(nearbyProfessionalsProvider(_selectedRadius));
    final popularProducts = ref.watch(popularProductsProvider);
    final banners     = ref.watch(bannersProvider);
    final unread      = ref.watch(unreadCountProvider);

    return CustomScrollView(
      slivers: [
        // ── Header vert ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Livraison à',
                              style: TextStyle(
                                fontFamily: 'Nunito', fontSize: 13,
                                color: Colors.white.withOpacity(0.8)),
                            ),
                            const Row(children: [
                              Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                              SizedBox(width: 2),
                              Text(
                                'Cotonou, Bénin',
                                style: TextStyle(
                                  fontFamily: 'Nunito', fontSize: 15,
                                  fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                              Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                            ]),
                          ],
                        ),
                      ),
                      _ClientHomeBell(unread: unread),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(user.avatarUrl!) : null,
                          child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                              ? Text(
                                  _avatarInitial(user?.displayName),
                                  style: const TextStyle(
                                    fontFamily: 'Nunito', color: Colors.white,
                                    fontWeight: FontWeight.w800, fontSize: 16),
                                )
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    // Barre de recherche (tap → /search)
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Row(children: [
                          Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.search, color: AppColors.grey, size: 22)),
                          Expanded(child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Text(
                              'Plat, restaurant, produit…',
                              style: TextStyle(
                                color: AppColors.grey, fontFamily: 'Nunito', fontSize: 15)),
                          )),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Chips rayon géo
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _radiusOptions.map((opt) {
                          final sel = _selectedRadius == opt.km;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedRadius = opt.km),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: sel ? Colors.white : Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(sel ? 0 : 0.5)),
                              ),
                              child: Text(
                                opt.label,
                                style: TextStyle(
                                  fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700,
                                  color: sel ? AppColors.primary : Colors.white,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Catégories ───────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.offWhite,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: _categories.map((c) {
                  final sel = c['id'] == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: sel ? AppColors.primary : AppColors.lightGrey),
                      ),
                      child: Row(children: [
                        Text(c['emoji']!, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          c['label']!,
                          style: TextStyle(
                            fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.darkGrey),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // ── Banners ──────────────────────────────────────────────────────────
        banners.when(
          data: (data) => data.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(child: _BannersCarousel(banners: data)),
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // ── Produits populaires ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(children: [
              const Text(
                'Produits populaires',
                style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.nearBlack),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/search'),
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.primary),
                ),
              ),
            ]),
          ),
        ),
        popularProducts.when(
          data: (products) => products.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: products.length,
                      itemBuilder: (ctx, i) => _ProductCard(product: products[i]),
                    ),
                  ),
                ),
          loading: () => SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: 5,
                itemBuilder: (_, __) => _ShimmerProductCard(),
              ),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // ── Titre établissements ──────────────────────────────────────────────
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(children: [
              Text(
                'Établissements',
                style: TextStyle(
                  fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.nearBlack),
              ),
              Spacer(),
              Text('🔥', style: TextStyle(fontSize: 18)),
            ]),
          ),
        ),

        // ── Liste établissements ──────────────────────────────────────────────
        professionals.when(
          data: (list) {
            final filtered = _selectedCategory == 'all'
                ? list
                : list.where((p) => p.category == _selectedCategory).toList();
            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(children: [
                      const Text('😔', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 12),
                      Text(
                        list.isEmpty
                            ? 'Aucun établissement disponible'
                            : 'Aucun établissement dans cette catégorie',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700,
                          color: AppColors.nearBlack),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        list.isEmpty
                            ? 'Aucun établissement validé pour le moment.'
                            : 'Essayez une autre catégorie.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => ref.invalidate(nearbyProfessionalsProvider(_selectedRadius)),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Réessayer'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(160, 44),
                          backgroundColor: AppColors.primary,
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RestaurantCard(pro: filtered[i]),
                  childCount: filtered.length,
                ),
              ),
            );
          },
          loading: () => SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ShimmerRestaurantCard(), childCount: 4),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGrey)),
                child: Column(children: [
                  const Text('📡', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  const Text(
                    'Connexion impossible',
                    style: TextStyle(
                      fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700,
                      color: AppColors.nearBlack)),
                  const SizedBox(height: 6),
                  const Text(
                    'Vérifiez votre connexion internet et réessayez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => ref.invalidate(nearbyProfessionalsProvider(_selectedRadius)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Text(
                        'Réessayer',
                        style: TextStyle(
                          fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Cartes produits ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/restaurant/${product.professionalId}'),
    child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            child: (product.imageUrl != null && product.imageUrl!.isNotEmpty)
                ? CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    height: 110, width: 140, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      height: 110, width: 140,
                      color: AppColors.primary.withOpacity(0.08),
                      child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36)))),
                  )
                : Container(
                    height: 110, width: 140,
                    color: AppColors.primary.withOpacity(0.08),
                    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36)))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.nearBlack),
                ),
                const SizedBox(height: 4),
                Text(
                  product.formattedPrice,
                  style: const TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800,
                    color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShimmerProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      width: 140, height: 184,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ── Cartes restaurant ─────────────────────────────────────────────────────────

class _RestaurantCard extends StatelessWidget {
  final Professional pro;
  const _RestaurantCard({required this.pro});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/restaurant/${pro.id}'),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            child: Stack(children: [
              (pro.coverImageUrl != null && pro.coverImageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: pro.coverImageUrl!,
                      height: 160, width: double.infinity, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        height: 160, color: AppColors.primary.withOpacity(0.08),
                        child: Center(child: Text(pro.categoryEmoji,
                            style: const TextStyle(fontSize: 52)))),
                    )
                  : Container(
                      height: 160, color: AppColors.primary.withOpacity(0.08),
                      child: Center(child: Text(pro.categoryEmoji,
                          style: const TextStyle(fontSize: 52)))),
              if (!pro.isOpen) Container(
                height: 160, color: Colors.black.withOpacity(0.4),
                child: const Center(child: Text(
                  'FERMÉ',
                  style: TextStyle(
                    fontFamily: 'Nunito', color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 2)))),
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: pro.isOpen ? AppColors.success : AppColors.grey,
                    borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    pro.isOpen ? 'Ouvert' : 'Fermé',
                    style: const TextStyle(
                      fontFamily: 'Nunito', color: Colors.white,
                      fontSize: 11, fontWeight: FontWeight.w700)),
                )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(
                    pro.businessName,
                    style: const TextStyle(
                      fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.nearBlack))),
                  if (pro.avgRating != null && (pro.avgRating ?? 0) > 0)
                    Row(children: [
                      const Icon(Icons.star_rounded, color: AppColors.yellow, size: 16),
                      const SizedBox(width: 2),
                      Text(
                        pro.avgRating!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.nearBlack)),
                    ]),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: AppColors.grey),
                  const SizedBox(width: 2),
                  Expanded(child: Text(
                    pro.city ?? '',
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey))),
                  if (pro.distance != null) ...[
                    const Icon(Icons.directions_bike_rounded, size: 14, color: AppColors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${pro.distance!.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
                  ],
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  _InfoChip(
                    icon: Icons.access_time_rounded,
                    label: '${pro.estimatedDeliveryMin ?? 25}-${(pro.estimatedDeliveryMin ?? 25) + 10} min'),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: Icons.delivery_dining_rounded,
                    label: (pro.deliveryFee ?? 0) == 0
                        ? 'Livraison gratuite'
                        : '${(pro.deliveryFee ?? 0).toStringAsFixed(0)} F'),
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.offWhite, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.grey),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(
          fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkGrey,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Banners ───────────────────────────────────────────────────────────────────

class _BannersCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const _BannersCarousel({required this.banners});

  @override
  State<_BannersCarousel> createState() => _BannersCarouselState();
}

class _BannersCarouselState extends State<_BannersCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) => Column(children: [
    SizedBox(
      height: 160,
      child: PageView.builder(
        itemCount: widget.banners.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) {
          final banner = widget.banners[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: banner['imageUrl'] ?? '',
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.2),
                  child: const Center(child: Text(
                    'ifè FOOD',
                    style: TextStyle(
                      fontFamily: 'Nunito', fontWeight: FontWeight.w800,
                      color: AppColors.primary, fontSize: 20)))),
              ),
            ),
          );
        },
      ),
    ),
    if (widget.banners.length > 1)
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(widget.banners.length, (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
          width: i == _current ? 16 : 6, height: 6,
          decoration: BoxDecoration(
            color: i == _current ? AppColors.primary : AppColors.lightGrey,
            borderRadius: BorderRadius.circular(3)),
        )),
      ),
  ]);
}

// ── Bell ──────────────────────────────────────────────────────────────────────

class _ClientHomeBell extends StatelessWidget {
  final int unread;
  const _ClientHomeBell({required this.unread});

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
    Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => context.push('/notifications'),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            unread > 0
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: Colors.white, size: 24,
          ),
        ),
      ),
    ),
    if (unread > 0) Positioned(
      right: 2, top: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          unread > 99 ? '99+' : '$unread',
          style: const TextStyle(
            fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w900,
            color: Colors.white)),
      ),
    ),
  ]);
}

// ── Shimmer restaurant ────────────────────────────────────────────────────────

class _ShimmerRestaurantCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12), height: 260,
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16))),
  );
}
