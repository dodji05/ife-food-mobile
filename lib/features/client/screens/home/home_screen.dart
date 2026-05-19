import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/professional.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notifications_provider.dart';

final nearbyProfessionalsProvider = FutureProvider.autoDispose<List<Professional>>((ref) async {
  final res = await ApiClient.instance.get('/geo/nearby', params: {
    'lat': AppConstants.defaultLat, 'lng': AppConstants.defaultLng, 'radius': 15
  });
  final list = res['data'] as List? ?? [];
  return list.map((e) => Professional.fromJson(e)).toList();
});

final bannersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/config/banners');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Extrait la 1ère lettre du nom pour l'avatar fallback.
/// Defensive : .substring(0,1) crashe si la string est vide (RangeError)
/// AVANT que `?? '?'` puisse réagir → on guarde explicitement.
String _avatarInitial(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  return name.trim().substring(0, 1).toUpperCase();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'all';

  final _categories = [
    {'id': 'all', 'label': 'Tout', 'emoji': '🌟'},
    {'id': 'RESTAURANT', 'label': 'Restos', 'emoji': '🍽️'},
    {'id': 'GROCERY', 'label': 'Épicerie', 'emoji': '🛒'},
    {'id': 'SUPERMARKET', 'label': 'Super', 'emoji': '🏪'},
    {'id': 'BAKERY', 'label': 'Boulang.', 'emoji': '🥖'},
    {'id': 'PHARMACY', 'label': 'Pharma', 'emoji': '💊'},
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final professionals = ref.watch(nearbyProfessionalsProvider);
    final banners = ref.watch(bannersProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(child: Container(
            color: AppColors.primary,
            child: SafeArea(bottom: false, child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Livraison à', style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.white.withOpacity(0.8))),
                    const Row(children: [
                      Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 2),
                      Text('Cotonou, Bénin', style: TextStyle(fontFamily: 'Nunito', fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                      Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                    ]),
                  ])),
                  // Bell variante claire (header primary) -> /notifications
                  _ClientHomeBell(unread: ref.watch(unreadCountProvider)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: CircleAvatar(
                      radius: 20, backgroundColor: Colors.white.withOpacity(0.2),
                      backgroundImage: (user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty)
                          ? NetworkImage(user.avatarUrl!) : null,
                      child: (user?.avatarUrl == null || user!.avatarUrl!.isEmpty)
                          // Guard contre RangeError : si displayName est vide,
                          // .substring(0,1) crashe AVANT que `?? '?'` puisse réagir.
                          ? Text(_avatarInitial(user?.displayName),
                              style: const TextStyle(fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))
                          : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                // Search bar — tap ouvre l'écran /search
                GestureDetector(
                  onTap: () => context.push('/search'),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))]),
                    child: const Row(children: [
                      Padding(padding: EdgeInsets.only(left: 16), child: Icon(Icons.search, color: AppColors.grey, size: 22)),
                      Expanded(child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        child: Text('Plat, restaurant, produit…',
                          style: TextStyle(color: AppColors.grey, fontFamily: 'Nunito', fontSize: 15)),
                      )),
                    ]),
                  ),
                ),
              ]),
            )),
          )),

          // Categories
          SliverPersistentHeader(
            pinned: true,
            delegate: _CatHeader(categories: _categories, selected: _selectedCategory, onSelect: (id) => setState(() => _selectedCategory = id)),
          ),

          // Banners
          banners.when(
            data: (data) => data.isEmpty ? const SliverToBoxAdapter() : SliverToBoxAdapter(child: _BannersCarousel(banners: data)),
            loading: () => const SliverToBoxAdapter(),
            error: (_, __) => const SliverToBoxAdapter(),
          ),

          // Section title
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
            child: Row(children: [
              const Text('Proches de vous', style: TextStyle(fontFamily: 'Nunito', fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.nearBlack)),
              const Spacer(),
              const Text('🔥', style: TextStyle(fontSize: 18)),
            ]),
          )),

          // Professionals list
          professionals.when(
            data: (list) {
              final filtered = _selectedCategory == 'all' ? list : list.where((p) => p.category == _selectedCategory).toList();
              if (filtered.isEmpty) return SliverToBoxAdapter(child: Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Column(children: [
                  const Text('😔', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 12),
                  Text(
                    list.isEmpty
                        ? 'Aucun établissement à proximité'
                        : 'Aucun établissement dans cette catégorie',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.nearBlack),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    list.isEmpty
                        ? 'Aucun pro validé dans 15 km autour de\nCotonou (${AppConstants.defaultLat.toStringAsFixed(4)}, ${AppConstants.defaultLng.toStringAsFixed(4)}).'
                        : 'Essayez une autre catégorie.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => ref.invalidate(nearbyProfessionalsProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(160, 44),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ])),
              ));
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RestaurantCard(pro: filtered[i]),
                  childCount: filtered.length,
                )),
              );
            },
            loading: () => SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ShimmerCard(), childCount: 5)),
            ),
            error: (e, _) => SliverToBoxAdapter(child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightGrey)),
                child: Column(children: [
                  const Text('📡', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  const Text('Connexion impossible', style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
                  const SizedBox(height: 6),
                  const Text('Vérifiez votre connexion internet et réessayez.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => ref.invalidate(nearbyProfessionalsProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Réessayer', style: TextStyle(fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

class _CatHeader extends SliverPersistentHeaderDelegate {
  final List<Map<String, String>> categories;
  final String selected;
  final Function(String) onSelect;
  const _CatHeader({required this.categories, required this.selected, required this.onSelect});

  @override double get minExtent => 68;
  @override double get maxExtent => 68;
  @override bool shouldRebuild(_) => true;

  @override
  Widget build(context, shrink, overlaps) => Container(
    color: Theme.of(context).scaffoldBackgroundColor,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: categories.map((c) {
        final sel = c['id'] == selected;
        return GestureDetector(
          onTap: () => onSelect(c['id']!),
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
              Text(c['label']!, style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.darkGrey)),
            ]),
          ),
        );
      }).toList()),
    ),
  );
}

class _BannersCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const _BannersCarousel({required this.banners});
  @override State<_BannersCarousel> createState() => _BannersCarouselState();
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
              child: CachedNetworkImage(imageUrl: banner['imageUrl'] ?? '', fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: AppColors.primary.withOpacity(0.2),
                  child: const Center(child: Text('ifè FOOD', style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 20))))),
            ),
          );
        },
      ),
    ),
    if (widget.banners.length > 1) Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.banners.length, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        width: i == _current ? 16 : 6, height: 6,
        decoration: BoxDecoration(color: i == _current ? AppColors.primary : AppColors.lightGrey, borderRadius: BorderRadius.circular(3)),
      )),
    ),
  ]);
}

class _RestaurantCard extends StatelessWidget {
  final Professional pro;
  const _RestaurantCard({required this.pro});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/restaurant/${pro.id}'),
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover image
        ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
          child: Stack(children: [
            pro.coverImageUrl != null
              ? CachedNetworkImage(imageUrl: pro.coverImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover)
              : Container(height: 160, color: AppColors.primary.withOpacity(0.08),
                  child: Center(child: Text(pro.categoryEmoji, style: const TextStyle(fontSize: 52)))),
            if (!pro.isOpen) Container(height: 160, color: Colors.black.withOpacity(0.4),
              child: const Center(child: Text('FERMÉ', style: TextStyle(fontFamily: 'Nunito', color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 2)))),
            // Status badge
            Positioned(top: 12, left: 12, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: pro.isOpen ? AppColors.success : AppColors.grey, borderRadius: BorderRadius.circular(8)),
              child: Text(pro.isOpen ? 'Ouvert' : 'Fermé', style: const TextStyle(fontFamily: 'Nunito', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
        // Info
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(pro.businessName, style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.nearBlack))),
              if (pro.avgRating != null && (pro.avgRating ?? 0) > 0) Row(children: [
                const Icon(Icons.star_rounded, color: AppColors.yellow, size: 16),
                const SizedBox(width: 2),
                Text(pro.avgRating!.toStringAsFixed(1), style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
              ]),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.grey),
              const SizedBox(width: 2),
              Expanded(child: Text(pro.city ?? '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey))),
              if (pro.distance != null) ...[
                const Icon(Icons.directions_bike_rounded, size: 14, color: AppColors.grey),
                const SizedBox(width: 4),
                Text('${pro.distance!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.grey)),
              ],
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _InfoChip(icon: Icons.access_time_rounded, label: '${pro.estimatedDeliveryMin ?? 25}-${(pro.estimatedDeliveryMin ?? 25) + 10} min'),
              const SizedBox(width: 8),
              _InfoChip(icon: Icons.delivery_dining_rounded, label: (pro.deliveryFee ?? 0) == 0 ? 'Livraison gratuite' : '${(pro.deliveryFee ?? 0).toStringAsFixed(0)} F'),
            ]),
          ]),
        ),
      ]),
    ),
  );
}

class _InfoChip extends StatelessWidget {
  final IconData icon; final String label;
  const _InfoChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppColors.offWhite, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.grey),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontFamily: 'Nunito', fontSize: 12, color: AppColors.darkGrey, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Bell variante claire (sur header primary) ──────────────────────────────
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
            unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
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
          color: AppColors.danger, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(unread > 99 ? '99+' : '$unread',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    ),
  ]);
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
    child: Container(margin: const EdgeInsets.only(bottom: 12), height: 260,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
  );
}
