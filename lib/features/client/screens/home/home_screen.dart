import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/product.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/notifications_provider.dart';
import '../../../../core/providers/location_provider.dart';
import '../../providers/addresses_provider.dart';
import '../../widgets/address_selector_modal.dart';
import '../../widgets/product_detail_modal.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final nearbyProfessionalsProvider =
    FutureProvider.autoDispose.family<List<Professional>, int>((ref, radius) async {
  final loc = ref.read(locationProvider);
  final lat = loc.position?.latitude  ?? AppConstants.defaultLat;
  final lng = loc.position?.longitude ?? AppConstants.defaultLng;
  final res = await ApiClient.instance.get('/geo/nearby', params: {
    'lat': lat,
    'lng': lng,
    'radius': radius == 0 ? 200 : radius,
  });
  final list = res['data'] as List? ?? [];
  return list.whereType<Map<String, dynamic>>().map(Professional.fromJson).toList();
});

final popularProductsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final loc = ref.read(locationProvider);
  final lat = loc.position?.latitude  ?? AppConstants.defaultLat;
  final lng = loc.position?.longitude ?? AppConstants.defaultLng;
  final res = await ApiClient.instance.get('/products/search', params: {
    'q': '',
    'lat': lat,
    'lng': lng,
  });
  final raw  = res['data'];
  final list = raw is List ? raw : (raw as Map<String, dynamic>?)?['items'] as List? ?? [];
  return list
      .take(16)
      .whereType<Map<String, dynamic>>()
      .map(Product.fromJson)
      .toList();
});

final bannersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final res = await ApiClient.instance.get('/config/banners');
  return List<Map<String, dynamic>>.from(res['data'] ?? []);
});

// ── Filtres ───────────────────────────────────────────────────────────────────

class HomeFilters {
  final double? minRating;
  final int?    maxDeliveryMin;
  final bool    openNow;

  const HomeFilters({this.minRating, this.maxDeliveryMin, this.openNow = false});

  bool get hasAny => minRating != null || maxDeliveryMin != null || openNow;
  int  get count  => (minRating != null ? 1 : 0) + (maxDeliveryMin != null ? 1 : 0) + (openNow ? 1 : 0);

  HomeFilters copyWith({
    Object? minRating     = _keep,
    Object? maxDeliveryMin = _keep,
    bool?   openNow,
  }) => HomeFilters(
    minRating:      minRating      == _keep ? this.minRating      : minRating as double?,
    maxDeliveryMin: maxDeliveryMin == _keep ? this.maxDeliveryMin : maxDeliveryMin as int?,
    openNow:        openNow ?? this.openNow,
  );

  List<Professional> apply(List<Professional> list) {
    var r = list;
    if (openNow)           r = r.where((p) => p.isOpen).toList();
    if (minRating != null) r = r.where((p) => (p.avgRating ?? 0) >= minRating!).toList();
    if (maxDeliveryMin != null) {
      r = r.where((p) => (p.estimatedDeliveryMin ?? 60) <= maxDeliveryMin!).toList();
    }
    return r;
  }

  static const _keep = Object();
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _avatarInitial(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  return name.trim().substring(0, 1).toUpperCase();
}

/// Retourne true si l'établissement ferme dans les 45 prochaines minutes.
bool _isClosingSoon(Professional pro) {
  if (!pro.isOpen || pro.openingHours == null) return false;
  final now = DateTime.now();
  const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final dayHours = pro.openingHours![dayKeys[now.weekday - 1]];
  if (dayHours is! Map) return false;
  final closeStr = dayHours['close'] as String?;
  if (closeStr == null) return false;
  final parts = closeStr.split(':');
  if (parts.length < 2) return false;
  try {
    final closeTime = DateTime(now.year, now.month, now.day,
        int.parse(parts[0]), int.parse(parts[1]));
    final diff = closeTime.difference(now).inMinutes;
    return diff > 0 && diff <= 45;
  } catch (_) {
    return false;
  }
}

// ── Écran principal ───────────────────────────────────────────────────────────

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String      _selectedCategory = 'all';
  int         _selectedRadius   = 0;
  HomeFilters _filters          = const HomeFilters();

  static const _radiusOptions = [
    (label: 'Tout',  km: 0),
    (label: '5 km',  km: 5),
    (label: '10 km', km: 10),
    (label: '20 km', km: 20),
  ];

  /// Lookup statique : sert à construire dynamiquement les catégories visibles.
  static const _kCategoryMeta = <String, Map<String, String>>{
    'all':         {'id': 'all',         'label': 'Tout',     'emoji': '🌟'},
    'RESTAURANT':  {'id': 'RESTAURANT',  'label': 'Restos',   'emoji': '🍽️'},
    'GROCERY':     {'id': 'GROCERY',     'label': 'Épicerie', 'emoji': '🛒'},
    'SUPERMARKET': {'id': 'SUPERMARKET', 'label': 'Super',    'emoji': '🏪'},
    'BAKERY':      {'id': 'BAKERY',      'label': 'Boulang.', 'emoji': '🥖'},
    'PHARMACY':    {'id': 'PHARMACY',    'label': 'Pharma',   'emoji': '💊'},
    'other':       {'id': 'other',       'label': 'Divers',   'emoji': '🏬'},
  };

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: _filters,
        onApply: (f) => setState(() => _filters = f),
      ),
    );
  }

  List<Professional> _applyCategory(List<Professional> list) {
    if (_selectedCategory == 'all') return list;
    if (_selectedCategory == 'other') {
      const known = {'RESTAURANT', 'GROCERY', 'SUPERMARKET', 'BAKERY', 'PHARMACY'};
      return list.where((p) => !known.contains(p.category)).toList();
    }
    return list.where((p) => p.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState   = ref.watch(authProvider);
    final user        = authState.user;
    final professionals = ref.watch(nearbyProfessionalsProvider(_selectedRadius));
    final popularProducts = ref.watch(popularProductsProvider);
    final banners     = ref.watch(bannersProvider);
    final unread      = ref.watch(unreadCountProvider);
    final defaultAddress = ref.watch(defaultAddressProvider);

    // ── Catégories visibles : "Tout" + celles ayant ≥1 établissement proche ─
    final List<Map<String, String>> visibleCategories = [
      _kCategoryMeta['all']!,
      ...professionals.maybeWhen(
        data: (list) {
          final seen    = <String>{};
          final result  = <Map<String, String>>[];
          bool hasOther = false;
          for (final p in list) {
            final cat = p.category;
            if (seen.add(cat)) {
              final meta = _kCategoryMeta[cat];
              if (meta != null) result.add(meta);
              else hasOther = true;
            }
          }
          if (hasOther) result.add(_kCategoryMeta['other']!);
          return result;
        },
        orElse: () => <Map<String, String>>[],
      ),
    ];
    // Si la catégorie sélectionnée disparaît (ex : changement de rayon), reset.
    if (_selectedCategory != 'all' &&
        visibleCategories.every((c) => c['id'] != _selectedCategory)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) { if (mounted) setState(() => _selectedCategory = 'all'); },
      );
    }

    return CustomScrollView(
      slivers: [
        // ── Header vert ──────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showAddressSelector(context);
                            if (picked != null) {
                              await ref.read(addressesNotifierProvider)
                                  .setDefault(picked.id);
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Livraison à',
                                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                                    color: Colors.white.withOpacity(0.8))),
                              Row(children: [
                                const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 2),
                                Flexible(child: Text(
                                  defaultAddress != null
                                      ? '${defaultAddress.label} — ${defaultAddress.city}'
                                      : 'Cotonou, Bénin',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                                      fontWeight: FontWeight.w700, color: Colors.white),
                                )),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 18),
                              ]),
                            ],
                          ),
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
                              ? Text(_avatarInitial(user?.displayName),
                                  style: const TextStyle(fontFamily: 'Nunito', color: Colors.white,
                                      fontWeight: FontWeight.w800, fontSize: 16))
                              : null,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    // Barre de recherche
                    GestureDetector(
                      onTap: () => context.push('/search'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: Icon(Icons.search, color: context.textMuted, size: 22)),
                          Expanded(child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                            child: Text('Plat, restaurant, boutique…',
                              style: TextStyle(color: context.textMuted,
                                  fontFamily: 'Nunito', fontSize: 15)))),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10)),
                            child: const Text('Chercher',
                              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                                  fontWeight: FontWeight.w700, color: AppColors.primary)),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Ligne rayon + filtre
                    Row(children: [
                      Expanded(
                        child: SingleChildScrollView(
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
                                        color: Colors.white.withOpacity(sel ? 0 : 0.5))),
                                  child: Row(children: [
                                    Icon(Icons.my_location_rounded,
                                      color: sel ? AppColors.primary : Colors.white, size: 11),
                                    const SizedBox(width: 4),
                                    Text(opt.label, style: TextStyle(
                                      fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700,
                                      color: sel ? AppColors.primary : Colors.white)),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _showFilters,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _filters.hasAny ? Colors.white : Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withOpacity(_filters.hasAny ? 0 : 0.5))),
                          child: Row(children: [
                            Icon(Icons.tune_rounded,
                              color: _filters.hasAny ? AppColors.primary : Colors.white, size: 15),
                            const SizedBox(width: 4),
                            Text('Filtres${_filters.hasAny ? ' (${_filters.count})' : ''}',
                              style: TextStyle(
                                fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700,
                                color: _filters.hasAny ? AppColors.primary : Colors.white)),
                          ]),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Catégories rapides ────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: context.bgColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: visibleCategories.map((c) {
                  final sel = c['id'] == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c['id']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : context.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: sel ? AppColors.primary : context.borderColor)),
                      child: Row(children: [
                        Text(c['emoji']!, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 5),
                        Text(c['label']!, style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.textSecondary)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // ── Filtres actifs (chips résumé) ─────────────────────────────────────
        if (_filters.hasAny)
          SliverToBoxAdapter(
            child: Container(
              color: context.bgColor,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        if (_filters.openNow)
                          _ActiveFilterChip(label: 'Ouvert maintenant',
                            onRemove: () => setState(() =>
                                _filters = _filters.copyWith(openNow: false))),
                        if (_filters.minRating != null)
                          _ActiveFilterChip(label: '${_filters.minRating!.toStringAsFixed(1)}★ min',
                            onRemove: () => setState(() =>
                                _filters = _filters.copyWith(minRating: null))),
                        if (_filters.maxDeliveryMin != null)
                          _ActiveFilterChip(label: '< ${_filters.maxDeliveryMin} min',
                            onRemove: () => setState(() =>
                                _filters = _filters.copyWith(maxDeliveryMin: null))),
                      ]),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _filters = const HomeFilters()),
                    child: const Text('Réinitialiser',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ),
                ]),
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

        // ── Nouveautés + Promos (sections horizontales dynamiques) ────────────
        if (professionals.value != null && professionals.value!.isNotEmpty)
          ..._buildDynamicSections(professionals.value!),

        // ── Produits populaires ───────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(children: [
              Text('Populaires près de vous',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
              const Spacer(),
              const Text('⭐', style: TextStyle(fontSize: 16)),
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
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Row(children: [
              Text('Établissements',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
              const Spacer(),
              if (_filters.hasAny)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                  child: const Text('Filtres actifs',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                        fontWeight: FontWeight.w700, color: AppColors.primary)),
                )
              else
                const Text('🏪', style: TextStyle(fontSize: 16)),
            ]),
          ),
        ),

        // ── Liste établissements ──────────────────────────────────────────────
        professionals.when(
          data: (list) {
            final byCat   = _applyCategory(list);
            final filtered = _filters.apply(byCat);
            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Column(children: [
                    const Text('😔', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(
                      list.isEmpty
                          ? 'Aucun établissement disponible'
                          : 'Aucun résultat avec ces filtres',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                          fontWeight: FontWeight.w700, color: context.textPrimary)),
                    const SizedBox(height: 6),
                    Text(
                      list.isEmpty
                          ? 'Aucun établissement validé pour le moment.'
                          : 'Modifiez vos filtres ou élargissez la zone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                          color: context.textMuted, height: 1.4)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _filters = const HomeFilters());
                        ref.invalidate(nearbyProfessionalsProvider(_selectedRadius));
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Réinitialiser'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(180, 44),
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ])),
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
                (ctx, i) => _ShimmerRestaurantCard(), childCount: 4)),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cardColor, borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor)),
                child: Column(children: [
                  const Text('📡', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text('Connexion impossible',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                        fontWeight: FontWeight.w700, color: context.textPrimary)),
                  const SizedBox(height: 6),
                  Text('Vérifiez votre connexion internet et réessayez.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => ref.invalidate(nearbyProfessionalsProvider(_selectedRadius)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Réessayer',
                        style: TextStyle(fontFamily: 'Nunito', color: Colors.white,
                            fontWeight: FontWeight.w700)),
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

  /// Construit les sections horizontales dynamiques à partir de la liste complète.
  List<Widget> _buildDynamicSections(List<Professional> list) {
    final top = list.where((p) => p.isOpen).toList()
      ..sort((a, b) => (b.avgRating ?? 0).compareTo(a.avgRating ?? 0));
    final promos = list.where((p) => (p.deliveryFee ?? 1) == 0).toList();
    return [
      ..._horizSection('🔥 Populaires maintenant', top.take(8).toList()),
      if (promos.isNotEmpty)
        ..._horizSection('🎁 Livraison gratuite', promos.take(8).toList()),
    ];
  }

  List<Widget> _horizSection(String title, List<Professional> items) {
    if (items.isEmpty) return [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(title,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                fontWeight: FontWeight.w800, color: context.textPrimary)),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: items.length,
            itemBuilder: (ctx, i) => _RestaurantMiniCard(pro: items[i]),
          ),
        ),
      ),
    ];
  }
}

// ── Filter Sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final HomeFilters current;
  final ValueChanged<HomeFilters> onApply;
  const _FilterSheet({required this.current, required this.onApply});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HomeFilters _local;

  @override
  void initState() {
    super.initState();
    _local = widget.current;
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Container(
        width: 40, height: 4,
        decoration: BoxDecoration(
          color: context.borderColor, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 20),
      Row(children: [
        Text('Filtres', style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
            fontWeight: FontWeight.w800, color: context.textPrimary)),
        const Spacer(),
        if (_local.hasAny) GestureDetector(
          onTap: () => setState(() => _local = const HomeFilters()),
          child: const Text('Réinitialiser', style: TextStyle(
            fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
            color: AppColors.primary)),
        ),
      ]),
      const SizedBox(height: 20),

      // Ouvert maintenant
      _filterRow(
        icon: Icons.store_rounded,
        label: 'Ouvert maintenant',
        child: Switch(
          value: _local.openNow,
          onChanged: (v) => setState(() => _local = _local.copyWith(openNow: v)),
          activeColor: AppColors.primary,
        ),
      ),
      Divider(height: 24, color: context.borderColor),

      // Note minimale
      Text('Note minimale',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
            fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 10),
      Row(children: [
        for (final r in [null, 3.0, 4.0, 4.5]) _RatingChip(
          label: r == null ? 'Toutes' : '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}★',
          selected: _local.minRating == r,
          onTap: () => setState(() => _local = _local.copyWith(minRating: r)),
        ),
      ]),
      Divider(height: 24, color: context.borderColor),

      // Temps de livraison
      Text('Temps de livraison',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
            fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 10),
      Row(children: [
        for (final t in [null, 20, 30, 45]) _RatingChip(
          label: t == null ? 'Tout' : '< $t min',
          selected: _local.maxDeliveryMin == t,
          onTap: () => setState(() => _local = _local.copyWith(maxDeliveryMin: t)),
        ),
      ]),

      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () { widget.onApply(_local); Navigator.pop(context); },
        child: const Text('Appliquer'),
      ),
    ]),
  );

  Widget _filterRow({required IconData icon, required String label, required Widget child}) =>
    Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(
        fontFamily: 'Nunito', fontSize: 14, fontWeight: FontWeight.w600,
        color: context.textPrimary))),
      child,
    ]);
}

class _RatingChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RatingChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : context.borderColor)),
      child: Text(label, style: TextStyle(
        fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
        color: selected ? Colors.white : context.textSecondary)),
    ),
  );
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(
        fontFamily: 'Nunito', fontSize: 12, fontWeight: FontWeight.w700,
        color: AppColors.primary)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary)),
    ]),
  );
}

// ── Restaurant mini card (sections horizontales) ──────────────────────────────

class _RestaurantMiniCard extends StatelessWidget {
  final Professional pro;
  const _RestaurantMiniCard({required this.pro});

  @override
  Widget build(BuildContext context) {
    final closingSoon = _isClosingSoon(pro);
    return GestureDetector(
      onTap: () => context.push('/restaurant/${pro.id}'),
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.borderColor.withOpacity(0.7))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13), topRight: Radius.circular(13)),
            child: Stack(children: [
              (pro.coverImageUrl != null && pro.coverImageUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: pro.coverImageUrl!,
                      height: 90, width: 150, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        height: 90, width: 150,
                        color: AppColors.primary.withOpacity(0.08),
                        child: Center(child: Text(pro.categoryEmoji,
                            style: const TextStyle(fontSize: 32)))))
                  : Container(
                      height: 90, width: 150,
                      color: AppColors.primary.withOpacity(0.08),
                      child: Center(child: Text(pro.categoryEmoji,
                          style: const TextStyle(fontSize: 32)))),
              // Badge statut temps réel
              Positioned(top: 6, left: 6, child: _StatusBadge(
                isOpen: pro.isOpen, closingSoon: closingSoon)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pro.businessName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 3),
              Row(children: [
                if (pro.avgRating != null && (pro.avgRating ?? 0) > 0) ...[
                  const Icon(Icons.star_rounded, color: AppColors.yellow, size: 12),
                  const SizedBox(width: 2),
                  Text(pro.avgRating!.toStringAsFixed(1),
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                        fontWeight: FontWeight.w700, color: context.textPrimary)),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.access_time_rounded, size: 11, color: context.textMuted),
                const SizedBox(width: 2),
                Text('${pro.estimatedDeliveryMin ?? 25} min',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 11, color: context.textMuted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Badge statut temps réel ───────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  final bool closingSoon;
  const _StatusBadge({required this.isOpen, required this.closingSoon});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;
    if (!isOpen) {
      bg = context.textMuted; label = 'Fermé';
    } else if (closingSoon) {
      bg = AppColors.warning; label = 'Ferme bientôt';
    } else {
      bg = AppColors.success; label = 'Ouvert';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
      child: Text(label, style: const TextStyle(
        fontFamily: 'Nunito', color: Colors.white, fontSize: 10,
        fontWeight: FontWeight.w700)),
    );
  }
}

// ── Cartes produits ───────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showProductDetail(
      context,
      product: product,
      professionalId: product.professionalId,
    ),
    child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: context.cardColor, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.8))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36)))))
              : Container(
                  height: 110, width: 140,
                  color: AppColors.primary.withOpacity(0.08),
                  child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 36)))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 4),
            Text(product.formattedPrice,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w800, color: AppColors.primary)),
          ]),
        ),
      ]),
    ),
  );
}

// ── Restaurant card (liste verticale) ────────────────────────────────────────

class _RestaurantCard extends StatelessWidget {
  final Professional pro;
  const _RestaurantCard({required this.pro});

  @override
  Widget build(BuildContext context) {
    final closingSoon = _isClosingSoon(pro);
    return GestureDetector(
      onTap: () => context.push('/restaurant/${pro.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor.withOpacity(0.8))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                            style: const TextStyle(fontSize: 52)))))
                  : Container(
                      height: 160, color: AppColors.primary.withOpacity(0.08),
                      child: Center(child: Text(pro.categoryEmoji,
                          style: const TextStyle(fontSize: 52)))),
              if (!pro.isOpen) Container(
                height: 160, color: Colors.black.withOpacity(0.4),
                child: const Center(child: Text('FERMÉ',
                  style: TextStyle(fontFamily: 'Nunito', color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 2)))),
              Positioned(top: 12, left: 12,
                child: _StatusBadge(isOpen: pro.isOpen, closingSoon: closingSoon)),
              // Badge livraison gratuite
              if ((pro.deliveryFee ?? 1) == 0) Positioned(top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.success, borderRadius: BorderRadius.circular(7)),
                  child: const Text('Livraison gratuite',
                    style: TextStyle(fontFamily: 'Nunito', color: Colors.white,
                        fontSize: 10, fontWeight: FontWeight.w700)),
                )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(pro.businessName,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
                      fontWeight: FontWeight.w800, color: context.textPrimary))),
                if (pro.avgRating != null && (pro.avgRating ?? 0) > 0)
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.yellow, size: 16),
                    const SizedBox(width: 2),
                    Text(pro.avgRating!.toStringAsFixed(1),
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                          fontWeight: FontWeight.w700, color: context.textPrimary)),
                  ]),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 14, color: context.textMuted),
                const SizedBox(width: 2),
                Expanded(child: Text(pro.city ?? '',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: context.textMuted))),
                if (pro.distance != null) ...[
                  Icon(Icons.directions_bike_rounded, size: 14, color: context.textMuted),
                  const SizedBox(width: 4),
                  Text('${pro.distance!.toStringAsFixed(1)} km',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: context.textMuted)),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _InfoChip(icon: Icons.access_time_rounded,
                  label: '${pro.estimatedDeliveryMin ?? 25}-${(pro.estimatedDeliveryMin ?? 25) + 10} min'),
                const SizedBox(width: 8),
                _InfoChip(icon: Icons.delivery_dining_rounded,
                  label: (pro.deliveryFee != null && pro.deliveryFee == 0)
                      ? 'Livraison gratuite'
                      : pro.deliveryFee != null
                          ? '${pro.deliveryFee!.toStringAsFixed(0)} F'
                          : 'Frais variables'),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: context.bgColor, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: context.textMuted),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
          color: context.textSecondary, fontWeight: FontWeight.w600)),
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
                imageUrl: banner['imageUrl'] ?? '', fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.10),
                  child: Center(child: Image.asset('assets/images/logo.png',
                      width: 64, height: 64, fit: BoxFit.contain)))),
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
            color: i == _current ? AppColors.primary : context.borderColor,
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
            color: Colors.white, size: 24),
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
          border: Border.all(color: AppColors.primary, width: 1.5)),
        alignment: Alignment.center,
        child: Text(unread > 99 ? '99+' : '$unread',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 10,
              fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    ),
  ]);
}

// ── Shimmers ──────────────────────────────────────────────────────────────────

class _ShimmerRestaurantCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
    child: Container(margin: const EdgeInsets.only(bottom: 12), height: 260,
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16))),
  );
}

class _ShimmerProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
    child: Container(width: 140, height: 184, margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(16))),
  );
}
