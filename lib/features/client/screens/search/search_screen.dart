import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/product.dart';

// ── Types de résultats ────────────────────────────────────────────────────────

enum _SearchTab { all, restaurants, products }

extension _SearchTabX on _SearchTab {
  String get label => switch (this) {
    _SearchTab.all         => 'Tout',
    _SearchTab.restaurants => 'Établissements',
    _SearchTab.products    => 'Produits',
  };
}

// ── Suggestions prédéfinies ───────────────────────────────────────────────────

const _suggestions = [
  ('🍕', 'Pizza'),
  ('🍔', 'Burger'),
  ('🍜', 'Riz / pâtes'),
  ('🥗', 'Salade'),
  ('🥖', 'Pain / boulangerie'),
  ('🍣', 'Poisson'),
  ('🍗', 'Poulet'),
  ('🥤', 'Boisson'),
  ('💊', 'Pharmacie'),
  ('🛒', 'Épicerie'),
];

// ── Écran ─────────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl   = TextEditingController();
  late final TabController _tabCtrl;

  List<Professional> _pros     = [];
  List<Product>      _products = [];
  bool               _loading  = false;
  String             _lastQuery = '';
  bool               _openNow  = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _SearchTab.values.length, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim() == _lastQuery) return;
    if (q.trim().length < 2) {
      setState(() { _pros = []; _products = []; _lastQuery = ''; });
      return;
    }
    _lastQuery = q.trim();
    setState(() => _loading = true);
    try {
      final [prosRes, productsRes] = await Future.wait([
        ApiClient.instance.get('/geo/nearby', params: {
          'lat': AppConstants.defaultLat,
          'lng': AppConstants.defaultLng,
          'radius': 200,
        }),
        ApiClient.instance.get('/products/search', params: {
          'q': q,
          'lat': AppConstants.defaultLat,
          'lng': AppConstants.defaultLng,
        }),
      ]);

      List unwrap(Map<String, dynamic> r) {
        final raw = r['data'];
        if (raw is List) return raw;
        if (raw is Map) return (raw['items'] as List?) ?? (raw['data'] as List?) ?? [];
        return [];
      }

      final qLower = q.toLowerCase();
      final allPros = unwrap(prosRes)
          .map((e) => Professional.fromJson(e as Map<String, dynamic>))
          .toList();
      final filteredPros = allPros.where((p) =>
          p.businessName.toLowerCase().contains(qLower) ||
          (p.description ?? '').toLowerCase().contains(qLower) ||
          (p.city ?? '').toLowerCase().contains(qLower) ||
          p.category.toLowerCase().contains(qLower)).toList();

      final prods = unwrap(productsRes)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _pros     = filteredPros;
        _products = prods;
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Professional> get _filteredPros =>
      _openNow ? _pros.where((p) => p.isOpen).toList() : _pros;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.offWhite,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: const BackButton(),
      title: TextField(
        controller: _ctrl,
        autofocus: true,
        onChanged: _search,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 16,
            fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Plat, restaurant, boutique, catégorie…',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          hintStyle: const TextStyle(color: AppColors.grey, fontFamily: 'Nunito'),
          contentPadding: EdgeInsets.zero,
          suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.grey, size: 20),
                  onPressed: () {
                    _ctrl.clear();
                    _search('');
                    setState(() {});
                  })
              : null,
        ),
      ),
      bottom: _ctrl.text.length >= 2
          ? TabBar(
              controller: _tabCtrl,
              labelStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  fontWeight: FontWeight.w500),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.grey,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              tabs: _SearchTab.values.map((t) {
                final count = switch (t) {
                  _SearchTab.all         => _filteredPros.length + _products.length,
                  _SearchTab.restaurants => _filteredPros.length,
                  _SearchTab.products    => _products.length,
                };
                return Tab(text: count > 0 ? '${t.label} ($count)' : t.label);
              }).toList(),
            )
          : null,
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _ctrl.text.length < 2
            ? _SuggestionsPanel(onTap: (s) {
                _ctrl.text = s;
                _ctrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: s.length));
                _search(s);
                setState(() {});
              })
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _AllResults(
                    pros: _filteredPros,
                    products: _products,
                    openNow: _openNow,
                    onToggleOpen: (v) => setState(() => _openNow = v),
                  ),
                  _RestaurantResults(pros: _filteredPros),
                  _ProductResults(products: _products),
                ],
              ),
  );
}

// ── Panneau suggestions ───────────────────────────────────────────────────────

class _SuggestionsPanel extends StatelessWidget {
  final ValueChanged<String> onTap;
  const _SuggestionsPanel({required this.onTap});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Suggestions',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
              fontWeight: FontWeight.w800, color: AppColors.grey, letterSpacing: 0.5))),
      ..._suggestions.map((item) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
        child: ListTile(
          leading: Text(item.$1, style: const TextStyle(fontSize: 22)),
          title: Text(item.$2,
            style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
          trailing: const Icon(Icons.north_west_rounded, size: 16, color: AppColors.grey),
          onTap: () => onTap(item.$2),
        ),
      )),
    ],
  );
}

// ── Onglet Tout ───────────────────────────────────────────────────────────────

class _AllResults extends StatelessWidget {
  final List<Professional> pros;
  final List<Product>      products;
  final bool               openNow;
  final ValueChanged<bool> onToggleOpen;
  const _AllResults({
    required this.pros, required this.products,
    required this.openNow, required this.onToggleOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (pros.isEmpty && products.isEmpty) return _emptyState();
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Toggle ouvert maintenant
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
        child: Row(children: [
          const Icon(Icons.store_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          const Expanded(child: Text('Ouvert maintenant',
            style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
                fontSize: 14, color: AppColors.nearBlack))),
          Switch(value: openNow, onChanged: onToggleOpen, activeColor: AppColors.primary),
        ]),
      ),
      if (pros.isNotEmpty) ...[
        _SectionHeader(label: 'Établissements', count: pros.length),
        ...pros.take(4).map((p) => _ProTile(pro: p)),
        if (pros.length > 4)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {},
              child: Text('Voir les ${pros.length - 4} autres →',
                style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                    fontWeight: FontWeight.w700, color: AppColors.primary)),
            ),
          ),
        const SizedBox(height: 8),
      ],
      if (products.isNotEmpty) ...[
        _SectionHeader(label: 'Produits', count: products.length),
        ...products.take(6).map((p) => _ProductTile(product: p)),
      ],
    ]);
  }
}

// ── Onglet Établissements ─────────────────────────────────────────────────────

class _RestaurantResults extends StatelessWidget {
  final List<Professional> pros;
  const _RestaurantResults({required this.pros});

  @override
  Widget build(BuildContext context) {
    if (pros.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pros.length,
      itemBuilder: (_, i) => _ProTile(pro: pros[i]),
    );
  }
}

// ── Onglet Produits ───────────────────────────────────────────────────────────

class _ProductResults extends StatelessWidget {
  final List<Product> products;
  const _ProductResults({required this.products});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: products.length,
      itemBuilder: (_, i) => _ProductTile(product: products[i]),
    );
  }
}

// ── Tuiles de résultats ───────────────────────────────────────────────────────

class _ProTile extends StatelessWidget {
  final Professional pro;
  const _ProTile({required this.pro});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (pro.coverImageUrl ?? pro.logoUrl) != null
            ? CachedNetworkImage(
                imageUrl: (pro.coverImageUrl ?? pro.logoUrl)!,
                width: 52, height: 52, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _EmojiBox(pro.categoryEmoji))
            : _EmojiBox(pro.categoryEmoji),
      ),
      title: Text(pro.businessName,
        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
            fontSize: 15)),
      subtitle: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: pro.isOpen
                ? AppColors.success.withOpacity(0.12)
                : AppColors.grey.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6)),
          child: Text(pro.isOpen ? 'Ouvert' : 'Fermé',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 11,
                fontWeight: FontWeight.w700,
                color: pro.isOpen ? AppColors.success : AppColors.grey)),
        ),
        if (pro.city != null)
          Expanded(child: Text(pro.city!,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: AppColors.grey), overflow: TextOverflow.ellipsis)),
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (pro.avgRating != null && (pro.avgRating ?? 0) > 0) ...[
          const Icon(Icons.star_rounded, color: AppColors.yellow, size: 14),
          const SizedBox(width: 2),
          Text(pro.avgRating!.toStringAsFixed(1),
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
                fontWeight: FontWeight.w700)),
          const SizedBox(width: 4),
        ],
        const Icon(Icons.chevron_right_rounded, color: AppColors.lightGrey),
      ]),
      onTap: () => context.push('/restaurant/${pro.id}'),
    ),
  );
}

class _ProductTile extends StatelessWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: product.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: product.imageUrl!,
                width: 52, height: 52, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _EmojiBox('🍽️'))
            : const _EmojiBox('🍽️'),
      ),
      title: Text(product.localizedName('fr'),
        style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
            fontSize: 15)),
      subtitle: Text(product.formattedPrice,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
            color: AppColors.primary, fontWeight: FontWeight.w800)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.lightGrey),
      onTap: () => context.push('/restaurant/${product.professionalId}'),
    ),
  );
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int    count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(label.toUpperCase(),
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w800, color: AppColors.grey, letterSpacing: 0.8)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
        child: Text('$count',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
              fontWeight: FontWeight.w700, color: AppColors.primary)),
      ),
    ]),
  );
}

class _EmojiBox extends StatelessWidget {
  final String emoji;
  const _EmojiBox(this.emoji);

  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    color: AppColors.primary.withOpacity(0.08),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))));
}

Widget _emptyState() => const Center(
  child: Padding(
    padding: EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('🔍', style: TextStyle(fontSize: 48)),
      SizedBox(height: 12),
      Text('Aucun résultat',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
      SizedBox(height: 8),
      Text('Essayez avec un autre mot-clé',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey),
        textAlign: TextAlign.center),
    ]),
  ),
);
