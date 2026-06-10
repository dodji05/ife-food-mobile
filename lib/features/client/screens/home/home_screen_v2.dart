// home_screen_v2.dart — Proposition de redesign de l'accueil client
// ⚠️  FICHIER PROPOSITIF — Ne pas fusionner sans validation UI
// L'original (home_screen.dart) n'est PAS modifié.
//
// Améliorations vs v1 :
//  1. Header gradient + salutation personnalisée
//  2. Catégories : icônes rondes colorées (style Uber Eats)
//  3. Banners auto-scroll (Timer 3 s) + indicateur de page amélioré
//  4. RestaurantCard compact horizontal (image 90×90 à gauche)
//  5. Rayon déplacé dans le bloc "Établissements" (plus dans le header)
//  6. SearchBar épurée sans bouton "Chercher" redondant
//  7. Section headers avec bouton "Voir tout"
//  8. Shimmer adapté aux nouvelles cartes

import 'dart:async';
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
// Réutilise les providers et helpers de home_screen.dart
import 'home_screen.dart'
    show
        nearbyProfessionalsProvider,
        popularProductsProvider,
        bannersProvider,
        HomeFilters;

// ── Catégories avec couleurs distinctives ─────────────────────────────────────

class _CategoryDef {
  final String id;
  final String label;
  final String emoji;
  final Color  color;
  const _CategoryDef(this.id, this.label, this.emoji, this.color);
}

/// Lookup statique id → métadonnées. Sert de référence pour construire
/// dynamiquement les catégories visibles (uniquement celles avec ≥1 établissement).
const _kCategoryMeta = <String, _CategoryDef>{
  'all':         _CategoryDef('all',         'Tout',     '🌟', Color(0xFF1A6B3C)),
  'RESTAURANT':  _CategoryDef('RESTAURANT',  'Restos',   '🍽️', Color(0xFFE85D04)),
  'GROCERY':     _CategoryDef('GROCERY',     'Épicerie', '🛒', Color(0xFF2196F3)),
  'SUPERMARKET': _CategoryDef('SUPERMARKET', 'Super',    '🏪', Color(0xFF9C27B0)),
  'BAKERY':      _CategoryDef('BAKERY',      'Boulang.', '🥖', Color(0xFFFF9800)),
  'PHARMACY':    _CategoryDef('PHARMACY',    'Pharma',   '💊', Color(0xFF00BCD4)),
  'other':       _CategoryDef('other',       'Divers',   '🏬', Color(0xFF607D8B)),
};

const _kRadiusOptions = [
  (label: 'Tout',   km: 0),
  (label: '5 km',   km: 5),
  (label: '10 km',  km: 10),
  (label: '20 km',  km: 20),
];

// ── Helpers ───────────────────────────────────────────────────────────────────

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  return name.trim().substring(0, 1).toUpperCase();
}

String _firstName(String? displayName) {
  if (displayName == null || displayName.isEmpty) return '';
  return displayName.trim().split(' ').first;
}

bool _isClosingSoon(Professional pro) {
  if (!pro.isOpen || pro.openingHours == null) return false;
  final now     = DateTime.now();
  const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  final dh      = pro.openingHours![dayKeys[now.weekday - 1]];
  if (dh is! Map) return false;
  final cs = dh['close'] as String?;
  if (cs == null) return false;
  final parts = cs.split(':');
  if (parts.length < 2) return false;
  try {
    final close = DateTime(
        now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    final diff = close.difference(now).inMinutes;
    return diff > 0 && diff <= 45;
  } catch (_) {
    return false;
  }
}

// ── Écran ─────────────────────────────────────────────────────────────────────

class HomeScreenV2 extends ConsumerStatefulWidget {
  const HomeScreenV2({super.key});
  @override
  ConsumerState<HomeScreenV2> createState() => _HomeScreenV2State();
}

class _HomeScreenV2State extends ConsumerState<HomeScreenV2> {
  String      _selectedCategory = 'all';
  int         _selectedRadius   = 0;
  HomeFilters _filters          = const HomeFilters();

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheetV2(
        current:  _filters,
        onApply:  (f) => setState(() => _filters = f),
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
    final user            = ref.watch(authProvider).user;
    final professionals   = ref.watch(nearbyProfessionalsProvider(_selectedRadius));
    final popularProducts = ref.watch(popularProductsProvider);
    final banners         = ref.watch(bannersProvider);
    final unread          = ref.watch(unreadCountProvider);
    final defaultAddr     = ref.watch(defaultAddressProvider);

    // ── Catégories visibles : "Tout" + celles ayant ≥1 établissement proche ─
    final List<_CategoryDef> visibleCategories = [
      _kCategoryMeta['all']!,
      ...professionals.maybeWhen(
        data: (list) {
          final seen   = <String>{};
          final defs   = <_CategoryDef>[];
          bool hasOther = false;
          for (final p in list) {
            final cat = p.category;
            if (seen.add(cat)) {
              final def = _kCategoryMeta[cat];
              if (def != null) defs.add(def);
              else hasOther = true;
            }
          }
          if (hasOther) defs.add(_kCategoryMeta['other']!);
          return defs;
        },
        orElse: () => <_CategoryDef>[],
      ),
    ];
    // Si la catégorie sélectionnée disparaît (ex : changement de rayon), reset.
    if (_selectedCategory != 'all' &&
        visibleCategories.every((c) => c.id != _selectedCategory)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) { if (mounted) setState(() => _selectedCategory = 'all'); },
      );
    }

    return CustomScrollView(
      slivers: [
        // ── 1. Header gradient ───────────────────────────────────────────────
        SliverToBoxAdapter(child: _Header(
          user: user,
          unread: unread,
          defaultAddress: defaultAddr?.label != null
              ? '${defaultAddr!.label} — ${defaultAddr.city}'
              : 'Cotonou, Bénin',
          onAddressTap: () async {
            final picked = await showAddressSelector(context);
            if (picked != null) {
              await ref.read(addressesNotifierProvider).setDefault(picked.id);
            }
          },
        )),

        // ── 2. Search bar ────────────────────────────────────────────────────
        SliverToBoxAdapter(child: _SearchBar()),

        // ── 3. Catégories icônes rondes ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: context.bgColor,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: visibleCategories.map((c) {
                  final sel = c.id == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 16),
                      child: Column(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            color: sel
                                ? c.color
                                : c.color.withOpacity(context.isDark ? 0.18 : 0.10),
                            shape: BoxShape.circle,
                            border: sel
                                ? null
                                : Border.all(color: c.color.withOpacity(0.3)),
                            boxShadow: sel ? [BoxShadow(
                              color: c.color.withOpacity(0.4),
                              blurRadius: 8, offset: const Offset(0, 3))] : null,
                          ),
                          child: Center(child: Text(c.emoji,
                              style: const TextStyle(fontSize: 24))),
                        ),
                        const SizedBox(height: 6),
                        Text(c.label, style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                          color: sel ? c.color : context.textSecondary,
                        )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),

        // ── 4. Chips filtres actifs ──────────────────────────────────────────
        if (_filters.hasAny)
          SliverToBoxAdapter(
            child: Container(
              color: context.bgColor,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Expanded(child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    if (_filters.openNow)
                      _ActiveChip(label: 'Ouvert maintenant',
                          onRemove: () => setState(() =>
                              _filters = _filters.copyWith(openNow: false))),
                    if (_filters.minRating != null)
                      _ActiveChip(
                          label: '${_filters.minRating!.toStringAsFixed(1)}★ min',
                          onRemove: () => setState(() =>
                              _filters = _filters.copyWith(minRating: null))),
                    if (_filters.maxDeliveryMin != null)
                      _ActiveChip(
                          label: '< ${_filters.maxDeliveryMin} min',
                          onRemove: () => setState(() =>
                              _filters = _filters.copyWith(maxDeliveryMin: null))),
                  ]),
                )),
                GestureDetector(
                  onTap: () => setState(() => _filters = const HomeFilters()),
                  child: const Text('Tout effacer',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ]),
            ),
          ),

        // ── 5. Banners auto-scroll ───────────────────────────────────────────
        banners.when(
          data: (data) => data.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(child: _BannersV2(banners: data)),
          loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // ── 6. Section populaires (scroll horizontal amélioré) ───────────────
        if (professionals.value != null && professionals.value!.isNotEmpty)
          ..._buildPopularSection(professionals.value!),

        // ── 7. Produits populaires ───────────────────────────────────────────
        SliverToBoxAdapter(child: _SectionHeader(
          title: 'Populaires près de vous',
          icon: '⭐',
          onViewAll: () => context.push('/search'),
        )),
        popularProducts.when(
          data: (products) => products.isEmpty
              ? const SliverToBoxAdapter(child: SizedBox.shrink())
              : SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: products.length,
                      itemBuilder: (ctx, i) => _ProductCardV2(product: products[i]),
                    ),
                  ),
                ),
          loading: () => SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: 5,
                itemBuilder: (_, __) => _ShimmerProduct(),
              ),
            ),
          ),
          error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
        ),

        // ── 8. Bloc établissements (avec sélecteur rayon intégré) ────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Établissements',
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 20,
                        fontWeight: FontWeight.w800, color: context.textPrimary)),
                  if (professionals.hasValue)
                    Text(
                      '${_filters.apply(_applyCategory(professionals.value!)).length} résultat(s)',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                          color: context.textMuted)),
                ],
              )),
              // Filtre
              GestureDetector(
                onTap: _showFilters,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _filters.hasAny
                        ? AppColors.primary
                        : context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _filters.hasAny
                            ? AppColors.primary
                            : context.borderColor)),
                  child: Row(children: [
                    Icon(Icons.tune_rounded, size: 15,
                        color: _filters.hasAny ? Colors.white : context.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                        'Filtres${_filters.hasAny ? ' (${_filters.count})' : ''}',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _filters.hasAny
                                ? Colors.white
                                : context.textSecondary)),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // Chips rayon (maintenant ici, plus dans le header)
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: _kRadiusOptions.map((opt) {
                final sel = _selectedRadius == opt.km;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRadius = opt.km),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : context.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.primary : context.borderColor)),
                    child: Row(children: [
                      Icon(Icons.my_location_rounded,
                          size: 12,
                          color: sel ? Colors.white : context.textMuted),
                      const SizedBox(width: 4),
                      Text(opt.label, style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : context.textSecondary)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── 9. Liste établissements (carte compacte horizontale) ──────────────
        professionals.when(
          data: (list) {
            final byCat   = _applyCategory(list);
            final filtered = _filters.apply(byCat);
            if (filtered.isEmpty) {
              return SliverToBoxAdapter(
                child: _EmptyState(
                  hasResults: list.isNotEmpty,
                  onReset: () {
                    setState(() => _filters = const HomeFilters());
                    ref.invalidate(nearbyProfessionalsProvider(_selectedRadius));
                  },
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _RestaurantCardV2(pro: filtered[i]),
                  childCount: filtered.length,
                ),
              ),
            );
          },
          loading: () => SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _ShimmerRestaurantCompact(), childCount: 5)),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _ErrorCard(
                onRetry: () =>
                    ref.invalidate(nearbyProfessionalsProvider(_selectedRadius)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildPopularSection(List<Professional> list) {
    final top = list.where((p) => p.isOpen).toList()
      ..sort((a, b) => (b.avgRating ?? 0).compareTo(a.avgRating ?? 0));
    final free = list.where((p) => (p.deliveryFee ?? 1) == 0).toList();
    return [
      if (top.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(
          title: '🔥 Populaires maintenant',
          onViewAll: () => context.push('/search'),
        )),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 196,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: top.take(8).length,
              itemBuilder: (ctx, i) =>
                  _RestaurantMiniCardV2(pro: top.take(8).toList()[i]),
            ),
          ),
        ),
      ],
      if (free.isNotEmpty) ...[
        SliverToBoxAdapter(child: _SectionHeader(
          title: '🎁 Livraison gratuite',
          onViewAll: () {},
        )),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 196,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: free.take(8).length,
              itemBuilder: (ctx, i) =>
                  _RestaurantMiniCardV2(pro: free.take(8).toList()[i]),
            ),
          ),
        ),
      ],
    ];
  }
}

// ── Header gradient ───────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final dynamic user;
  final int     unread;
  final String  defaultAddress;
  final VoidCallback onAddressTap;

  const _Header({
    required this.user,
    required this.unread,
    required this.defaultAddress,
    required this.onAddressTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = _firstName(user?.displayName);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            const Color(0xFF1D8348), // vert légèrement plus clair
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : salutation + cloche + avatar
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text(
                        firstName.isNotEmpty
                            ? 'Bonjour, $firstName 👋'
                            : 'Bonjour 👋',
                        style: const TextStyle(
                          fontFamily: 'Nunito', fontSize: 22,
                          fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    const Text('Que voulez-vous aujourd\'hui ?',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                          color: Colors.white70)),
                  ],
                )),
                // Cloche
                _BellButton(unread: unread),
                const SizedBox(width: 8),
                // Avatar
                GestureDetector(
                  onTap: () => context.go('/profile'),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white.withOpacity(0.25),
                    backgroundImage: (user?.avatarUrl != null &&
                            (user?.avatarUrl as String).isNotEmpty)
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: (user?.avatarUrl == null ||
                            (user?.avatarUrl as String?)?.isEmpty == true)
                        ? Text(_initials(user?.displayName),
                            style: const TextStyle(
                                fontFamily: 'Nunito', color: Colors.white,
                                fontWeight: FontWeight.w800, fontSize: 16))
                        : null,
                  ),
                ),
              ]),

              const SizedBox(height: 16),

              // Ligne 2 : adresse de livraison
              GestureDetector(
                onTap: onAddressTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Livraison à',
                            style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                                color: Colors.white70)),
                          Text(defaultAddress,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Nunito',
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cloche ────────────────────────────────────────────────────────────────────

class _BellButton extends StatelessWidget {
  final int unread;
  const _BellButton({required this.unread});

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
            color: Colors.white, size: 26),
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

// ── Barre de recherche épurée ─────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: context.bgColor,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
    child: GestureDetector(
      onTap: () => context.push('/search'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.3 : 0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(children: [
          Icon(Icons.search_rounded, color: context.textMuted, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text('Plat, restaurant, boutique…',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                color: context.textMuted))),
          Icon(Icons.mic_none_rounded, color: context.textMuted, size: 20),
        ]),
      ),
    ),
  );
}

// ── Header de section ─────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String    title;
  final String?   icon;
  final VoidCallback? onViewAll;

  const _SectionHeader({required this.title, this.icon, this.onViewAll});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
    child: Row(children: [
      if (icon != null) ...[
        Text(icon!, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
      ],
      Expanded(child: Text(title,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
            fontWeight: FontWeight.w800, color: context.textPrimary))),
      if (onViewAll != null)
        GestureDetector(
          onTap: onViewAll,
          child: Text('Voir tout',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                fontWeight: FontWeight.w700, color: AppColors.primary)),
        ),
    ]),
  );
}

// ── Banners auto-scroll ───────────────────────────────────────────────────────

class _BannersV2 extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  const _BannersV2({required this.banners});

  @override
  State<_BannersV2> createState() => _BannersV2State();
}

class _BannersV2State extends State<_BannersV2> {
  late final PageController _ctrl = PageController(viewportFraction: 0.88);
  int    _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.banners.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        final next = (_current + 1) % widget.banners.length;
        _ctrl.animateToPage(next,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    SizedBox(
      height: 170,
      child: PageView.builder(
        controller: _ctrl,
        itemCount: widget.banners.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (ctx, i) {
          final b = widget.banners[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(children: [
                CachedNetworkImage(
                  imageUrl: b['imageUrl'] ?? '',
                  width: double.infinity, height: 170,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.primary.withOpacity(0.15),
                    child: const Center(child: Text('ifè FOOD',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 22,
                          fontWeight: FontWeight.w800, color: AppColors.primary))))),
                // Gradient overlay bas
                Positioned.fill(child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                      ],
                    ),
                  ),
                )),
                // Titre du banner si présent
                if (b['title'] != null)
                  Positioned(left: 16, bottom: 14,
                    child: Text(b['title'],
                      style: const TextStyle(fontFamily: 'Nunito',
                          color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w800,
                          shadows: [Shadow(blurRadius: 8,
                              color: Colors.black54)]))),
              ]),
            ),
          );
        },
      ),
    ),
    if (widget.banners.length > 1)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _current ? 20 : 6, height: 6,
            decoration: BoxDecoration(
              color: i == _current
                  ? AppColors.primary
                  : context.borderColor,
              borderRadius: BorderRadius.circular(3)),
          )),
        ),
      ),
  ]);
}

// ── Mini-card restaurant (scroll horizontal) ──────────────────────────────────

class _RestaurantMiniCardV2 extends StatelessWidget {
  final Professional pro;
  const _RestaurantMiniCardV2({required this.pro});

  @override
  Widget build(BuildContext context) {
    final closing = _isClosingSoon(pro);
    return GestureDetector(
      onTap: () => context.push('/restaurant/${pro.id}'),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor.withOpacity(0.7)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.2 : 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            child: Stack(children: [
              (pro.coverImageUrl?.isNotEmpty == true)
                  ? CachedNetworkImage(
                      imageUrl: pro.coverImageUrl!,
                      height: 104, width: 170, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _PlaceholderImg(
                          height: 104, width: 170, emoji: pro.categoryEmoji))
                  : _PlaceholderImg(height: 104, width: 170, emoji: pro.categoryEmoji),
              // Gradient overlay + badge
              Positioned.fill(child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.25)],
                  ),
                ),
              )),
              Positioned(top: 8, left: 8,
                child: _StatusPill(isOpen: pro.isOpen, closingSoon: closing)),
              if ((pro.deliveryFee ?? 1) == 0)
                Positioned(top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success, borderRadius: BorderRadius.circular(6)),
                    child: const Text('🎁',
                        style: TextStyle(fontSize: 12)),
                  )),
            ]),
          ),
          // Infos
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pro.businessName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                if ((pro.avgRating ?? 0) > 0) ...[
                  const Icon(Icons.star_rounded, color: AppColors.yellow, size: 13),
                  const SizedBox(width: 2),
                  Text(pro.avgRating!.toStringAsFixed(1),
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        fontWeight: FontWeight.w700, color: context.textPrimary)),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.access_time_rounded, size: 12, color: context.textMuted),
                const SizedBox(width: 2),
                Text('${pro.estimatedDeliveryMin ?? 25} min',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: context.textMuted)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── RestaurantCard compacte (liste verticale) ─────────────────────────────────
// Style horizontal : image 90×90 à gauche, infos à droite
// Avantage : 2× plus de cartes visibles à l'écran sans scroller

class _RestaurantCardV2 extends StatelessWidget {
  final Professional pro;
  const _RestaurantCardV2({required this.pro});

  @override
  Widget build(BuildContext context) {
    final closing = _isClosingSoon(pro);
    return GestureDetector(
      onTap: () => context.push('/restaurant/${pro.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderColor.withOpacity(0.7)),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(context.isDark ? 0.2 : 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image carrée 90×90
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(children: [
              (pro.coverImageUrl?.isNotEmpty == true)
                  ? CachedNetworkImage(
                      imageUrl: pro.coverImageUrl!,
                      height: 90, width: 90, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _PlaceholderImg(height: 90, width: 90, emoji: pro.categoryEmoji))
                  : _PlaceholderImg(height: 90, width: 90, emoji: pro.categoryEmoji),
              if (!pro.isOpen) Container(
                height: 90, width: 90, color: Colors.black54,
                alignment: Alignment.center,
                child: const Text('FERMÉ',
                  style: TextStyle(fontFamily: 'Nunito', color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1))),
            ]),
          ),

          const SizedBox(width: 12),

          // Infos
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nom + note
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(pro.businessName,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                      fontWeight: FontWeight.w800, color: context.textPrimary))),
                if ((pro.avgRating ?? 0) > 0) ...[
                  const SizedBox(width: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.yellow, size: 14),
                    const SizedBox(width: 2),
                    Text(pro.avgRating!.toStringAsFixed(1),
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary)),
                  ]),
                ],
              ]),

              const SizedBox(height: 5),

              // Ville + distance
              Row(children: [
                Icon(Icons.location_on_rounded, size: 13, color: context.textMuted),
                const SizedBox(width: 2),
                Expanded(child: Text(
                  [pro.city, if (pro.distance != null)
                    '${pro.distance!.toStringAsFixed(1)} km']
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: context.textMuted))),
              ]),

              const SizedBox(height: 8),

              // Badges : statut · temps · frais
              Wrap(spacing: 6, runSpacing: 4, children: [
                _StatusPill(isOpen: pro.isOpen, closingSoon: closing),
                _PillInfo(
                  icon: Icons.access_time_rounded,
                  label: '${pro.estimatedDeliveryMin ?? 25}-'
                      '${(pro.estimatedDeliveryMin ?? 25) + 10} min',
                ),
                _PillInfo(
                  icon: Icons.delivery_dining_rounded,
                  label: (pro.deliveryFee != null && pro.deliveryFee == 0)
                      ? 'Gratuit'
                      : pro.deliveryFee != null
                          ? '${pro.deliveryFee!.toStringAsFixed(0)} F'
                          : 'Variable',
                  highlight: (pro.deliveryFee ?? 1) == 0,
                ),
              ]),
            ],
          )),

          // Chevron
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right_rounded,
                color: context.borderColor, size: 20),
          ),
        ]),
      ),
    );
  }
}

// ── Produit card ──────────────────────────────────────────────────────────────

class _ProductCardV2 extends StatelessWidget {
  final Product product;
  const _ProductCardV2({required this.product});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showProductDetail(context,
        product: product, professionalId: product.professionalId),
    child: Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor.withOpacity(0.8)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(context.isDark ? 0.2 : 0.05),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15), topRight: Radius.circular(15)),
          child: (product.imageUrl?.isNotEmpty == true)
              ? CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  height: 110, width: 140, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      _PlaceholderImg(height: 110, width: 140, emoji: '🍽️'))
              : _PlaceholderImg(height: 110, width: 140, emoji: '🍽️'),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.name, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
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

// ── Petits widgets réutilisables ──────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final bool isOpen;
  final bool closingSoon;
  const _StatusPill({required this.isOpen, required this.closingSoon});

  @override
  Widget build(BuildContext context) {
    final Color  bg;
    final String label;
    if (!isOpen)         { bg = context.textMuted;    label = 'Fermé'; }
    else if (closingSoon){ bg = AppColors.warning;    label = 'Ferme bientôt'; }
    else                 { bg = AppColors.success;    label = 'Ouvert'; }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontFamily: 'Nunito',
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _PillInfo extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     highlight;
  const _PillInfo({required this.icon, required this.label, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: highlight
          ? AppColors.success.withOpacity(0.12)
          : context.bgColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11,
          color: highlight ? AppColors.success : context.textMuted),
      const SizedBox(width: 3),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
          fontWeight: FontWeight.w600,
          color: highlight ? AppColors.success : context.textSecondary)),
    ]),
  );
}

class _PlaceholderImg extends StatelessWidget {
  final double height;
  final double width;
  final String emoji;
  const _PlaceholderImg(
      {required this.height, required this.width, required this.emoji});

  @override
  Widget build(BuildContext context) => Container(
    height: height, width: width,
    color: AppColors.primary.withOpacity(0.08),
    child: Center(child: Text(emoji,
        style: TextStyle(fontSize: height * 0.33))),
  );
}

class _ActiveChip extends StatelessWidget {
  final String       label;
  final VoidCallback onRemove;
  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.12),
      borderRadius: BorderRadius.circular(16)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontFamily: 'Nunito',
          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove,
        child: const Icon(Icons.close_rounded, size: 14, color: AppColors.primary)),
    ]),
  );
}

// ── États vide & erreur ───────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool         hasResults;
  final VoidCallback onReset;
  const _EmptyState({required this.hasResults, required this.onReset});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(child: Column(children: [
      Text(hasResults ? '🔍' : '😔',
          style: const TextStyle(fontSize: 52)),
      const SizedBox(height: 12),
      Text(
        hasResults
            ? 'Aucun résultat avec ces filtres'
            : 'Aucun établissement disponible',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
            fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 6),
      Text(
        hasResults
            ? 'Modifiez vos filtres ou élargissez la zone.'
            : 'Aucun établissement validé pour le moment.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
            color: context.textMuted, height: 1.5)),
      if (hasResults) ...[
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Réinitialiser les filtres'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 44),
            backgroundColor: AppColors.primary),
        ),
      ],
    ])),
  );
}

class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
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
      Text('Vérifiez votre connexion et réessayez.',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: context.textMuted)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(160, 44),
          backgroundColor: AppColors.primary),
      ),
    ]),
  );
}

// ── Shimmers ──────────────────────────────────────────────────────────────────

class _ShimmerRestaurantCompact extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: context.isDark ? Colors.grey[800]! : Colors.grey[200]!,
    highlightColor: context.isDark ? Colors.grey[700]! : Colors.grey[100]!,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 114,
      decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(16))),
  );
}

class _ShimmerProduct extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor: context.isDark ? Colors.grey[800]! : Colors.grey[200]!,
    highlightColor: context.isDark ? Colors.grey[700]! : Colors.grey[100]!,
    child: Container(
      width: 140, height: 184, margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
          color: context.cardColor, borderRadius: BorderRadius.circular(16))),
  );
}

// ── Sheet filtre (réutilise la même logique que home_screen.dart) ─────────────

class _FilterSheetV2 extends StatefulWidget {
  final HomeFilters              current;
  final ValueChanged<HomeFilters> onApply;
  const _FilterSheetV2({required this.current, required this.onApply});
  @override
  State<_FilterSheetV2> createState() => _FilterSheetV2State();
}

class _FilterSheetV2State extends State<_FilterSheetV2> {
  late HomeFilters _local;
  @override void initState() { super.initState(); _local = widget.current; }

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.cardColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
    padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
    child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.store_rounded,
              color: AppColors.primary, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text('Ouvert maintenant',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w600, color: context.textPrimary))),
        Switch(
          value: _local.openNow,
          onChanged: (v) => setState(() => _local = _local.copyWith(openNow: v)),
          activeColor: AppColors.primary),
      ]),
      Divider(height: 24, color: context.borderColor),
      // Note
      Text('Note minimale', style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
          fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 10),
      Row(children: [
        for (final r in [null, 3.0, 4.0, 4.5])
          _FilterChip(
            label: r == null ? 'Toutes' : '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}★',
            selected: _local.minRating == r,
            onTap: () => setState(() => _local = _local.copyWith(minRating: r))),
      ]),
      Divider(height: 24, color: context.borderColor),
      // Temps
      Text('Temps de livraison', style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
          fontWeight: FontWeight.w700, color: context.textPrimary)),
      const SizedBox(height: 10),
      Row(children: [
        for (final t in [null, 20, 30, 45])
          _FilterChip(
            label: t == null ? 'Tout' : '< $t min',
            selected: _local.maxDeliveryMin == t,
            onTap: () => setState(() => _local = _local.copyWith(maxDeliveryMin: t))),
      ]),
      const SizedBox(height: 24),
      ElevatedButton(
        onPressed: () { widget.onApply(_local); Navigator.pop(context); },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: const Text('Appliquer les filtres',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
              fontWeight: FontWeight.w800)),
      ),
    ]),
  );
}

class _FilterChip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

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
        border: Border.all(
            color: selected ? AppColors.primary : context.borderColor)),
      child: Text(label, style: TextStyle(
        fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
        color: selected ? Colors.white : context.textSecondary)),
    ),
  );
}
