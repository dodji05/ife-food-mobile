import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/currency_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/product.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_detail_modal.dart';
import '../../widgets/scheduled_delivery_dialog.dart';

// ── Modèle avis ───────────────────────────────────────────────────────────────

class _Review {
  final String  id;
  final double  proRating;
  final String? comment;
  final String? reply;
  final DateTime createdAt;
  final String? clientName;
  final String? clientAvatar;

  const _Review({
    required this.id,
    required this.proRating,
    this.comment,
    this.reply,
    required this.createdAt,
    this.clientName,
    this.clientAvatar,
  });

  factory _Review.fromJson(Map<String, dynamic> j) {
    final client = j['client'] as Map<String, dynamic>?;
    return _Review(
      id:           j['id']           as String? ?? '',
      proRating:    (j['professionalRating'] as num?)?.toDouble() ?? 0,
      comment:      j['professionalComment'] as String?,
      reply:        j['proReply']      as String?,
      createdAt:    DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
      clientName:   client?['firstName'] as String?,
      clientAvatar: client?['avatarUrl'] as String?,
    );
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final restaurantDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final res = await ApiClient.instance.get('/professionals/$id');
  return res['data'] as Map<String, dynamic>;
});

// ⚠️ Ce provider est conservé pour rétro-compatibilité (ex. home_screen) mais
// n'est PLUS utilisé dans RestaurantScreen — les produits sont désormais embarqués
// directement dans restaurantDetailProvider (GET /professionals/:id).
final restaurantProductsProvider =
    FutureProvider.autoDispose.family<List<Product>, String>((ref, id) async {
  final res = await ApiClient.instance.get('/products/professional/$id');
  final raw = res['data'];
  final list = raw is List ? raw : (raw as Map<String, dynamic>?)?['data'] as List? ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(Product.fromJson)
      .toList();
});

final restaurantReviewsProvider =
    FutureProvider.autoDispose.family<List<_Review>, String>((ref, id) async {
  final res = await ApiClient.instance.get('/reviews/professional/$id');
  // Backend returns { data: { reviews: [...], average: X, count: N } }
  final dataRaw = res['data'];
  final list = dataRaw is List     ? dataRaw
      : (dataRaw is Map ? dataRaw['reviews'] as List? : null) ?? [];
  return list
      .whereType<Map<String, dynamic>>()
      .map(_Review.fromJson)
      .toList();
});

// ── Écran principal ───────────────────────────────────────────────────────────

class RestaurantScreen extends ConsumerStatefulWidget {
  final String restaurantId;
  const RestaurantScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantScreen> createState() => _RestaurantScreenState();
}

class _RestaurantScreenState extends ConsumerState<RestaurantScreen>
    with TickerProviderStateMixin {
  late final TabController    _mainTab;
  late final ScrollController _outerCtrl;
  String _selectedCatId = '__all__';

  @override
  void initState() {
    super.initState();
    _mainTab   = TabController(length: 2, vsync: this);
    _mainTab.addListener(() => setState(() {}));
    _outerCtrl = ScrollController();
    // Dès le premier rendu, sauter directement à la position du TabBar
    // (collapse la SliverAppBar + passe le bloc infos) pour que le menu
    // soit immédiatement visible sans que le client ait à scroller.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_outerCtrl.hasClients &&
          _outerCtrl.position.maxScrollExtent > 0) {
        _outerCtrl.jumpTo(_outerCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _mainTab.dispose();
    _outerCtrl.dispose();
    super.dispose();
  }

  Future<void> _sharePro(Professional pro) async {
    final deepLink = '${AppConstants.websiteUrl}/restaurant/${pro.id}';
    final msg = '🍽️ Découvre "${pro.businessName}" sur ifè FOOD !\n'
        '${pro.categoryEmoji} ${_categoryLabel(pro.category)}'
        '${pro.city != null ? ' • ${pro.city}' : ''}\n\n$deepLink';
    await Share.share(msg, subject: pro.businessName);
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final detail  = ref.watch(restaurantDetailProvider(widget.restaurantId));
    final reviews = ref.watch(restaurantReviewsProvider(widget.restaurantId));
    final cart    = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: context.bgColor,
      floatingActionButton: cart.totalItems > 0
          ? _CartFab(cart: cart)
          : null,
      body: detail.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Erreur')),
          body: Center(child: Text(e.toString())),
        ),
        data: (json) {
          final pro = Professional.fromJson(json);

          // ── Produits embarqués dans GET /professionals/:id ──────────────
          // Plus de second appel /products/professional/:id — les produits
          // (tous, y compris rupture/indisponibles) arrivent dans la même
          // réponse. Cela évite les désynchronisations et les cas où le
          // second appel retournait vide alors que les produits existent.
          final rawProducts = json['products'];
          final prodList = rawProducts is List
              ? rawProducts
                  .whereType<Map<String, dynamic>>()
                  .map(Product.fromJson)
                  .toList()
              : <Product>[];

          // Groupement par catégorie
          final grouped = <String, List<Product>>{};
          final catLabels = <String, String>{};
          for (final p in prodList) {
            final key = p.categoryId ?? '__other__';
            grouped.putIfAbsent(key, () => []).add(p);
          }
          // Labels depuis productCategories embarquées
          final rawCatsRaw = json['productCategories'];
          final rawCats = rawCatsRaw is List ? rawCatsRaw : <dynamic>[];
          for (final c in rawCats) {
            if (c is! Map) continue;
            final id = c['id'] as String?;
            final name = c['name'];
            if (id != null) {
              final nm = name is Map ? (name['fr'] ?? name['en'] ?? '') : (name ?? '');
              catLabels[id] = nm.toString();
            }
          }
          final catKeys = grouped.keys.toList();

          return NestedScrollView(
            controller: _outerCtrl,
            headerSliverBuilder: (ctx, innerScrolled) => [
              // Cover + logo overlay
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                stretch: true,
                backgroundColor: AppColors.primary,
                leading: _CircleBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => context.pop()),
                actions: [
                  _CircleBtn(
                    icon: Icons.share_rounded,
                    onTap: () => _sharePro(pro)),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  stretchModes: const [StretchMode.zoomBackground],
                  background: Stack(children: [
                    // Photo de couverture
                    Positioned.fill(
                      child: pro.coverImageUrl != null
                          ? ColorFiltered(
                              colorFilter: ColorFilter.mode(
                                  Colors.black.withOpacity(0.25), BlendMode.darken),
                              child: CachedNetworkImage(
                                  imageUrl: pro.coverImageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.primary.withOpacity(0.7),
                                    child: Center(child: Text(pro.categoryEmoji,
                                        style: const TextStyle(fontSize: 72))))))
                          : Container(
                              color: AppColors.primary.withOpacity(0.8),
                              child: Center(child: Text(pro.categoryEmoji,
                                  style: const TextStyle(fontSize: 72)))),
                    ),
                    // Logo overlay (coin bas-gauche)
                    if (pro.logoUrl != null && pro.logoUrl!.isNotEmpty)
                      Positioned(
                        bottom: 16, left: 20,
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8)],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: CachedNetworkImage(
                              imageUrl: pro.logoUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.primary.withOpacity(0.1),
                                child: Center(child: Text(pro.categoryEmoji,
                                    style: const TextStyle(fontSize: 28))))),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),

              // Bloc informations
              SliverToBoxAdapter(
                child: Container(
                  color: context.cardColor,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    (pro.logoUrl != null && pro.logoUrl!.isNotEmpty) ? 12 : 20,
                    20, 16,
                  ),
                  child: _InfoSection(
                    pro: pro,
                    onCall: pro.phone != null ? () => _callPhone(pro.phone!) : null,
                  ),
                ),
              ),

              // Séparateur
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // TabBar pinned
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  tabController: _mainTab,
                  reviewCount: reviews.valueOrNull?.length,
                  innerBoxIsScrolled: innerScrolled,
                ),
              ),
            ],

            body: TabBarView(
              controller: _mainTab,
              children: [
                // ── Onglet Menu ──────────────────────────────────────────
                _MenuTab(
                  products: prodList,
                  grouped: grouped,
                  catLabels: catLabels,
                  catKeys: catKeys,
                  selectedCatId: _selectedCatId,
                  onCatSelect: (id) => setState(() => _selectedCatId = id),
                  professionalId: pro.id,
                  proName: pro.businessName,
                  // produits déjà chargés avec le détail — on wrap en AsyncData
                  productsAsync: AsyncValue.data(prodList),
                  isProOpen: pro.isOpen,
                  openingHours: pro.openingHours,
                ),
                // ── Onglet Avis ──────────────────────────────────────────
                _ReviewsTab(
                  reviewsAsync: reviews,
                  pro: pro,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Bloc informations établissement ──────────────────────────────────────────

class _InfoSection extends StatefulWidget {
  final Professional pro;
  final VoidCallback? onCall;
  const _InfoSection({required this.pro, this.onCall});

  @override
  State<_InfoSection> createState() => _InfoSectionState();
}

class _InfoSectionState extends State<_InfoSection> {
  bool _hoursExpanded = false;

  Professional get pro => widget.pro;

  /// Retourne les horaires du jour sous forme "{open} — {close}" ou "Fermé".
  String get _todayHours {
    final hours = pro.openingHours;
    if (hours == null) return '';
    const dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final dayKey  = dayKeys[DateTime.now().weekday - 1];
    final day     = hours[dayKey];
    if (day is! Map) return 'Fermé aujourd\'hui';
    final o = day['open']  as String?;
    final c = day['close'] as String?;
    if (o == null && c == null) return 'Fermé aujourd\'hui';
    return '${o ?? '?'} — ${c ?? '?'}';
  }

  static const _dayLabels = {
    'mon': 'Lun', 'tue': 'Mar', 'wed': 'Mer',
    'thu': 'Jeu', 'fri': 'Ven', 'sat': 'Sam', 'sun': 'Dim',
  };

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Nom + badge statut
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Text(pro.businessName,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 22,
                fontWeight: FontWeight.w800, color: context.textPrimary)),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: pro.isOpen
                ? AppColors.success.withOpacity(0.12)
                : AppColors.grey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8)),
          child: Text(pro.isOpen ? '● Ouvert' : '● Fermé',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                fontWeight: FontWeight.w700,
                color: pro.isOpen ? AppColors.success : AppColors.grey)),
        ),
      ]),
      const SizedBox(height: 4),
      // Catégorie
      Row(children: [
        Text(pro.categoryEmoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(_categoryLabel(pro.category),
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              color: context.textMuted, fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 10),
      // Note + nombre d'avis
      Row(children: [
        RatingBarIndicator(
          rating: pro.avgRating ?? 0,
          itemBuilder: (_, __) =>
              const Icon(Icons.star_rounded, color: AppColors.yellow),
          itemSize: 18,
          itemCount: 5,
        ),
        const SizedBox(width: 6),
        Text('${(pro.avgRating ?? 0).toStringAsFixed(1)} '
            '(${pro.reviewCount} avis)',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              color: context.textMuted)),
      ]),
      const SizedBox(height: 12),
      // Pills : délai + frais + distance
      Wrap(spacing: 8, runSpacing: 8, children: [
        _InfoPill(
          icon: Icons.access_time_rounded,
          label: '${pro.estimatedDeliveryMin ?? 25}–'
              '${(pro.estimatedDeliveryMin ?? 25) + 15} min'),
        _InfoPill(
          icon: Icons.delivery_dining_rounded,
          label: (pro.deliveryFee != null && pro.deliveryFee == 0)
              ? 'Livraison gratuite'
              : pro.deliveryFee != null
                  ? '${pro.deliveryFee!.toStringAsFixed(0)} F'
                  : 'Frais variables'),
        if (pro.distance != null)
          _InfoPill(
            icon: Icons.near_me_rounded,
            label: '${pro.distance!.toStringAsFixed(1)} km'),
        if (pro.city != null)
          _InfoPill(icon: Icons.location_on_rounded, label: pro.city!),
      ]),
      if (pro.description != null && pro.description!.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(pro.description!,
          style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
              color: context.textMuted, height: 1.5)),
      ],
      Divider(height: 24, color: context.borderColor),
      // Adresse
      if (pro.address != null) ...[
        _DetailRow(
          icon: Icons.location_on_rounded,
          child: Text(pro.address!,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                color: context.textPrimary))),
        const SizedBox(height: 10),
      ],
      // Téléphone (cliquable)
      if (pro.phone != null) ...[
        GestureDetector(
          onTap: widget.onCall,
          child: _DetailRow(
            icon: Icons.phone_rounded,
            child: Text(pro.phone!,
              style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: AppColors.primary, fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline))),
        ),
        const SizedBox(height: 10),
      ],
      // Horaires
      if (pro.openingHours != null) ...[
        GestureDetector(
          onTap: () => setState(() => _hoursExpanded = !_hoursExpanded),
          child: _DetailRow(
            icon: Icons.schedule_rounded,
            child: Row(children: [
              Expanded(child: Text(_todayHours,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    color: context.textPrimary))),
              Icon(
                _hoursExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: context.textMuted, size: 18),
            ]),
          ),
        ),
        if (_hoursExpanded) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 30),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.bgColor,
              borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: _dayLabels.entries.map((entry) {
                final hours = pro.openingHours![entry.key];
                final String label;
                if (hours is Map) {
                  final o = hours['open']  as String? ?? '';
                  final c = hours['close'] as String? ?? '';
                  label = '$o — $c';
                } else {
                  label = 'Fermé';
                }
                final isToday = _dayLabels.keys.toList()
                    .indexOf(entry.key) == DateTime.now().weekday - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    SizedBox(
                      width: 36,
                      child: Text(entry.value,
                        style: TextStyle(
                          fontFamily: 'Nunito', fontSize: 12,
                          fontWeight: isToday
                              ? FontWeight.w800 : FontWeight.w600,
                          color: isToday
                              ? AppColors.primary : context.textMuted))),
                    Text(label,
                      style: TextStyle(
                        fontFamily: 'Nunito', fontSize: 12,
                        color: isToday
                            ? context.textPrimary : context.textMuted,
                        fontWeight: isToday
                            ? FontWeight.w700 : FontWeight.w500)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    ]);
  }
}

// ── Onglet Menu ───────────────────────────────────────────────────────────────

class _MenuTab extends ConsumerWidget {
  final List<Product>        products;
  final Map<String, List<Product>> grouped;
  final Map<String, String>  catLabels;
  final List<String>         catKeys;
  final String               selectedCatId;
  final ValueChanged<String> onCatSelect;
  final String               professionalId;
  final String               proName;
  final AsyncValue<List<Product>> productsAsync;
  final bool isProOpen;
  final Map<String, dynamic>? openingHours;

  const _MenuTab({
    required this.products,
    required this.grouped,
    required this.catLabels,
    required this.catKeys,
    required this.selectedCatId,
    required this.onCatSelect,
    required this.professionalId,
    required this.proName,
    required this.productsAsync,
    required this.isProOpen,
    this.openingHours,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return productsAsync.when(
      loading: () => ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) => _ShimmerProductCard()),
      error: (e, _) => CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📡', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(e.toString(),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Nunito', color: context.textMuted)),
            ],
          ))),
        ),
      ]),
      data: (_) {
        final filtered = selectedCatId == '__all__'
            ? products
            : (grouped[selectedCatId] ?? []);

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Catégories chips (si plusieurs catégories)
            if (catKeys.length > 1)
              SliverPersistentHeader(
                pinned: true,
                delegate: _CatChipsDelegate(
                  keys: ['__all__', ...catKeys],
                  labels: {'__all__': 'Tous', ...catLabels},
                  selected: selectedCatId,
                  onSelect: onCatSelect,
                ),
              ),

            // SliverFillRemaining pour l'état vide : remplit l'espace
            // restant du viewport et centre le contenu correctement.
            // SliverToBoxAdapter seul ne suffit pas dans NestedScrollView
            // — le viewport reste blanc car le sliver est trop court.
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text('🍽️', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    Text('Aucun produit disponible',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                          color: context.textMuted)),
                  ]),
                )),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _ProductItem(
                      product: filtered[i],
                      professionalId: professionalId,
                      proName: proName,
                      isProOpen: isProOpen,
                      openingHours: openingHours,
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── Onglet Avis ───────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final AsyncValue<List<_Review>> reviewsAsync;
  final Professional pro;
  const _ReviewsTab({required this.reviewsAsync, required this.pro});

  @override
  Widget build(BuildContext context) => reviewsAsync.when(
    loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary)),
    error:   (_, __) => Center(
        child: Text('Impossible de charger les avis.',
          style: TextStyle(fontFamily: 'Nunito', color: context.textMuted))),
    data: (reviews) {
      if (reviews.isEmpty) {
        // NestedScrollView + TabBarView impose un enfant scrollable.
        // SliverFillRemaining(hasScrollBody:false) centre le contenu
        // dans l'espace restant sans provoquer d'overflow.
        return CustomScrollView(slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('⭐', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('Aucun avis pour le moment',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
                      fontWeight: FontWeight.w700, color: context.textPrimary)),
                const SizedBox(height: 6),
                Text('Soyez le premier à donner votre avis !',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                      color: context.textMuted)),
              ]),
            )),
          ),
        ]);
      }

      // Distribution des notes
      final counts = List.filled(6, 0); // index 0 unused
      for (final r in reviews) {
        final star = r.proRating.round().clamp(1, 5);
        counts[star]++;
      }
      final maxCount = counts.reduce((a, b) => a > b ? a : b).toDouble();

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Résumé note
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor)),
            child: Row(children: [
              Column(children: [
                Text((pro.avgRating ?? 0).toStringAsFixed(1),
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 40,
                      fontWeight: FontWeight.w900, color: context.textPrimary)),
                RatingBarIndicator(
                  rating: pro.avgRating ?? 0,
                  itemBuilder: (_, __) =>
                      const Icon(Icons.star_rounded, color: AppColors.yellow),
                  itemSize: 18, itemCount: 5),
                const SizedBox(height: 4),
                Text('${reviews.length} avis',
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: context.textMuted)),
              ]),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: List.generate(5, (i) {
                    final star  = 5 - i;
                    final count = counts[star];
                    final ratio = maxCount > 0 ? count / maxCount : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Text('$star',
                          style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 12, color: context.textMuted)),
                        const SizedBox(width: 4),
                        const Icon(Icons.star_rounded,
                            color: AppColors.yellow, size: 12),
                        const SizedBox(width: 6),
                        Expanded(child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio,
                            backgroundColor: context.borderColor,
                            valueColor: const AlwaysStoppedAnimation(
                                AppColors.yellow),
                            minHeight: 6,
                          ),
                        )),
                        const SizedBox(width: 6),
                        Text('$count',
                          style: TextStyle(fontFamily: 'Nunito',
                              fontSize: 11, color: context.textMuted)),
                      ]),
                    );
                  }),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // Liste des avis
          ...reviews.map((r) => _ReviewCard(review: r)),
        ],
      );
    },
  );
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name     = review.clientName?.trim() ?? '';
    final initials = name.isEmpty ? '?' : name[0].toUpperCase();
    final diff     = DateTime.now().difference(review.createdAt);
    final dateStr  = diff.inDays > 30
        ? '${(diff.inDays / 30).floor()} mois'
        : diff.inDays > 0
            ? 'il y a ${diff.inDays} j'
            : 'aujourd\'hui';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: review.clientAvatar != null
                ? NetworkImage(review.clientAvatar!) : null,
            child: review.clientAvatar == null
                ? Text(initials,
                    style: const TextStyle(fontFamily: 'Nunito',
                        fontWeight: FontWeight.w800, fontSize: 14,
                        color: AppColors.primary))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(review.clientName ?? 'Client anonyme',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                    fontWeight: FontWeight.w700, color: context.textPrimary)),
              Text(dateStr,
                style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                    color: context.textMuted)),
            ],
          )),
          RatingBarIndicator(
            rating: review.proRating,
            itemBuilder: (_, __) =>
                const Icon(Icons.star_rounded, color: AppColors.yellow),
            itemSize: 16, itemCount: 5),
        ]),
        if (review.comment != null && review.comment!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(review.comment!,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                color: context.textPrimary, height: 1.5)),
        ],
        // Réponse du pro
        if (review.reply != null && review.reply!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.store_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text(review.reply!,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                      color: AppColors.primary, height: 1.4))),
              ]),
          ),
        ],
      ]),
    );
  }
}

// ── Carte produit ─────────────────────────────────────────────────────────────

class _ProductItem extends ConsumerStatefulWidget {
  final Product product;
  final String professionalId;
  final String proName;
  final bool isProOpen;
  final Map<String, dynamic>? openingHours;
  const _ProductItem({
    required this.product,
    required this.professionalId,
    required this.proName,
    required this.isProOpen,
    this.openingHours,
  });

  @override
  ConsumerState<_ProductItem> createState() => _ProductItemState();
}

class _ProductItemState extends ConsumerState<_ProductItem> {
  Future<void> _addWithGuard() async {
    DateTime? scheduledFor;
    if (!widget.isProOpen) {
      final nextOpening = nextOpeningTime(widget.openingHours);
      final ok = await showScheduledDeliveryDialog(context, nextOpening: nextOpening);
      if (!ok || !mounted) return;
      scheduledFor = nextOpening;
    }
    final notifier = ref.read(cartProvider.notifier);
    if (notifier.canAddFrom(widget.professionalId)) {
      notifier.addItem(widget.product, widget.professionalId);
      if (scheduledFor != null) notifier.setScheduledDelivery(scheduledFor);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Changer de restaurant ?'),
        content: Text(
          'Votre panier contient des articles d\'un autre établissement. '
          'Voulez-vous le vider pour commander chez "${widget.proName}" ?',
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
    notifier.addItem(widget.product, widget.professionalId);
    if (scheduledFor != null) notifier.setScheduledDelivery(scheduledFor);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${widget.product.localizedName('fr')} ajouté.'),
      backgroundColor: AppColors.success,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cart     = ref.watch(cartProvider);
    final cartItem = cart.items.where((i) => i.product.id == widget.product.id).firstOrNull;
    final qty      = cartItem?.quantity ?? 0;
    final product  = widget.product;
    // Distinguer rupture de stock (temporaire) vs produit désactivé (indisponible)
    final outOfStock  = product.isOutOfStock;
    final notAvailable = !product.isAvailable;
    final canAddToCart = !outOfStock && !notAvailable;

    return Opacity(
      opacity: (outOfStock || notAvailable) ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: () => showProductDetail(
          context,
          product: product,
          professionalId: widget.professionalId,
          proName: widget.proName,
          isProOpen: widget.isProOpen,
          openingHours: widget.openingHours,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: context.cardColor, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.borderColor.withOpacity(0.8))),
          child: Row(children: [
          // Vignette produit
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(13)),
              child: product.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      width: 100, height: 100, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _ProductPlaceholder())
                  : _ProductPlaceholder(),
            ),
            // Overlay rupture de stock (orange) ou indisponible (rouge)
            if (outOfStock || notAvailable) Positioned.fill(
              child: ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(13)),
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: Center(child: Text(
                    outOfStock ? 'Rupture\nde stock' : 'Indisponible',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Nunito', color: Colors.white,
                      fontSize: 10, fontWeight: FontWeight.w700,
                      shadows: [Shadow(
                        color: outOfStock ? AppColors.warning : AppColors.danger,
                        blurRadius: 8)],
                    ))),
                ),
              ),
            ),
          ]),
          // Infos
          Expanded(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + badge état
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(product.localizedName('fr'),
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 14,
                        fontWeight: FontWeight.w700, color: context.textPrimary))),
                  if (outOfStock) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.warning.withOpacity(0.4))),
                      child: const Text('Rupture',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 9,
                            fontWeight: FontWeight.w800, color: AppColors.warning)),
                    ),
                  ] else if (notAvailable) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.danger.withOpacity(0.3))),
                      child: const Text('Indispo',
                        style: TextStyle(fontFamily: 'Nunito', fontSize: 9,
                            fontWeight: FontWeight.w800, color: AppColors.danger)),
                    ),
                  ],
                ]),
                if (product.localizedDescription('fr') != null &&
                    product.localizedDescription('fr')!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(product.localizedDescription('fr')!,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                        color: context.textMuted, height: 1.4)),
                ],
                if (product.preparationTimeMin != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.timer_outlined,
                        size: 11, color: context.textMuted),
                    const SizedBox(width: 3),
                    Text('${product.preparationTimeMin} min',
                      style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                          color: context.textMuted)),
                  ]),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  PriceText(amount: product.price,
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 15,
                        fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const Spacer(),
                  // Compteur panier — masqué si rupture ou indisponible
                  if (canAddToCart) ...[
                    if (qty == 0)
                      GestureDetector(
                        onTap: _addWithGuard,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 18)))
                    else
                      Row(children: [
                        GestureDetector(
                          onTap: () => ref.read(cartProvider.notifier)
                              .updateQuantity(product.id, qty - 1),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: context.borderColor,
                              borderRadius: BorderRadius.circular(6)),
                            child: Icon(Icons.remove_rounded,
                                size: 15, color: context.textPrimary))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('$qty',
                            style: const TextStyle(fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800, fontSize: 15))),
                        GestureDetector(
                          onTap: _addWithGuard,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.add_rounded,
                                size: 15, color: Colors.white))),
                      ]),
                  ],
                ]),
              ],
            ),
          )),
        ]),
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 100, height: 100, color: context.bgColor,
    child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 34))));
}

// ── CartFab ───────────────────────────────────────────────────────────────────

class _CartFab extends StatelessWidget {
  final CartState cart;
  const _CartFab({required this.cart});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.push('/cart'),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary, borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.4),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 22),
          Positioned(
            right: -6, top: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.yellow, shape: BoxShape.circle),
              child: Text('${cart.totalItems}',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 10,
                    fontWeight: FontWeight.w900, color: AppColors.nearBlack)),
            ),
          ),
        ]),
        const SizedBox(width: 10),
        Consumer(builder: (_, ref, __) => Text(
          'Voir le panier · ${ref.watch(currencyFormatterProvider).format(cart.subtotal)}',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w800, color: Colors.white))),
      ]),
    ),
  );
}

// ── Delegates SliverPersistentHeader ──────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabController tabController;
  final int?          reviewCount;
  final bool          innerBoxIsScrolled;
  const _TabBarDelegate({
    required this.tabController,
    this.reviewCount,
    required this.innerBoxIsScrolled,
  });

  @override double get minExtent => 48;
  @override double get maxExtent => 48;
  @override bool shouldRebuild(_TabBarDelegate old) =>
      old.reviewCount != reviewCount || old.innerBoxIsScrolled != innerBoxIsScrolled;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        decoration: BoxDecoration(
          color: context.cardColor,
          border: Border(bottom: BorderSide(
            color: overlapsContent || innerBoxIsScrolled
                ? context.borderColor : Colors.transparent))),
        child: TabBar(
          controller: tabController,
          labelStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 14,
              fontWeight: FontWeight.w500),
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.grey,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          tabs: [
            const Tab(text: 'Menu'),
            Tab(text: reviewCount != null ? 'Avis ($reviewCount)' : 'Avis'),
          ],
        ),
      );
}

class _CatChipsDelegate extends SliverPersistentHeaderDelegate {
  final List<String>        keys;
  final Map<String, String> labels;
  final String              selected;
  final ValueChanged<String> onSelect;
  const _CatChipsDelegate({
    required this.keys, required this.labels,
    required this.selected, required this.onSelect,
  });

  @override double get minExtent => 56;
  @override double get maxExtent => 56;
  @override bool shouldRebuild(_CatChipsDelegate old) =>
      old.selected != selected || old.keys.length != keys.length;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(
        color: context.bgColor,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: keys.map((id) {
              final label = labels[id] ?? id;
              final sel   = id == selected;
              return GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : context.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? AppColors.primary : context.borderColor)),
                  child: Text(label, style: TextStyle(
                    fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : context.textSecondary)),
                ),
              );
            }).toList(),
          ),
        ),
      );
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: context.bgColor, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
          fontWeight: FontWeight.w700, color: context.textSecondary)),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Widget   child;
  const _DetailRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(child: child),
    ],
  );
}

class _CircleBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.all(8),
      width: 36, height: 36,
      decoration: const BoxDecoration(
          color: Colors.white, shape: BoxShape.circle),
      child: Icon(icon, color: AppColors.nearBlack, size: 20)),
  );
}

class _ShimmerProductCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 100,
      decoration: BoxDecoration(
        color: context.borderColor,
        borderRadius: BorderRadius.circular(14)));
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _categoryLabel(String cat) => switch (cat.toUpperCase()) {
  'RESTAURANT'  => 'Restaurant',
  'BAKERY'      => 'Boulangerie',
  'GROCERY'     => 'Épicerie',
  'SUPERMARKET' => 'Supermarché',
  'PHARMACY'    => 'Pharmacie',
  _             => cat,
};
