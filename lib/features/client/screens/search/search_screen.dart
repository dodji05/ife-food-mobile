import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Écran de recherche unifié — V2
//
// Différences clés vs V1 :
//  • Appel UNIQUE à `/search/suggest` qui retourne en une fois les
//    établissements, produits et catégories matchant la query (ILIKE côté
//    SQL, multilingue fr/en, case-insensitive, paramétré).
//  • Debounce 250 ms : on n'appelle plus l'API à chaque frappe.
//  • Affichage segmenté par section avec petits compteurs.
//  • Clic catégorie → réutilise le label comme nouvelle query (drill-down).
//  • État vide propre + bouton "Effacer" rapide.
//
// Le backend filtre déjà sur status=VALIDATED & isAvailable=true, donc on
// fait confiance au payload côté UI.
// ─────────────────────────────────────────────────────────────────────────────

// ── Modèles légers (vue uniquement, pas réutilisés ailleurs) ─────────────────

class _Establishment {
  final String  id;
  final String  businessName;
  final String  category;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? city;
  final bool    isOpen;
  const _Establishment(this.id, this.businessName, this.category,
      this.logoUrl, this.coverImageUrl, this.city, this.isOpen);

  factory _Establishment.fromJson(Map<String, dynamic> j) => _Establishment(
    j['id'] as String? ?? '',
    j['businessName'] as String? ?? '',
    (j['category'] as String? ?? '').toUpperCase(),
    j['logoUrl'] as String?,
    j['coverImageUrl'] as String?,
    j['city'] as String?,
    j['isOpen'] as bool? ?? false,
  );
}

class _SuggestProduct {
  final String  id;
  final String  professionalId;
  final String  professionalName;
  final String? professionalLogoUrl;
  final String  nameFr;
  final double  price;
  final String  currency;
  final String? imageUrl;
  const _SuggestProduct(this.id, this.professionalId, this.professionalName,
      this.professionalLogoUrl, this.nameFr, this.price, this.currency, this.imageUrl);

  factory _SuggestProduct.fromJson(Map<String, dynamic> j) {
    String name = '';
    final n = j['name'];
    if (n is Map) name = (n['fr'] ?? n['en'] ?? '').toString();
    else if (n is String) name = n;
    return _SuggestProduct(
      j['id']             as String? ?? '',
      j['professionalId'] as String? ?? '',
      j['professionalName'] as String? ?? '',
      j['professionalLogoUrl'] as String?,
      name,
      (j['price']    as num?)?.toDouble() ?? 0,
      j['currency'] as String? ?? 'XOF',
      j['imageUrl'] as String?,
    );
  }
}

class _SuggestCategory {
  final String id;
  final String name;
  final String? icon;
  const _SuggestCategory(this.id, this.name, this.icon);

  factory _SuggestCategory.fromJson(Map<String, dynamic> j) {
    String name = '';
    final n = j['name'];
    if (n is Map) name = (n['fr'] ?? n['en'] ?? '').toString();
    else if (n is String) name = n;
    return _SuggestCategory(
      j['id'] as String? ?? '',
      name,
      j['icon'] as String?,
    );
  }
}

class _Suggestions {
  final List<_Establishment>    establishments;
  final List<_SuggestProduct>   products;
  final List<_SuggestCategory>  categories;
  const _Suggestions(this.establishments, this.products, this.categories);

  bool get isEmpty =>
      establishments.isEmpty && products.isEmpty && categories.isEmpty;

  int get total => establishments.length + products.length + categories.length;

  static const empty = _Suggestions([], [], []);
}

// ── Trending depuis la BDD ───────────────────────────────────────────────────

class _Trending {
  final List<_SuggestCategory> categories;
  final List<_Establishment>   establishments;
  const _Trending(this.categories, this.establishments);
  static const empty = _Trending([], []);
  bool get isEmpty => categories.isEmpty && establishments.isEmpty;
}

// ── Écran ────────────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();

  Timer?         _debounce;
  String         _lastQuery   = '';
  _Suggestions   _suggestions = _Suggestions.empty;
  bool           _loading     = false;
  String?        _errorMsg;

  _Trending      _trending    = _Trending.empty;
  bool           _trendingLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _trendingLoading = true);
    try {
      final res = await ApiClient.instance.get('/search/trending');
      final data = res['data'] as Map<String, dynamic>? ?? {};
      final cats = (data['categories'] as List? ?? [])
          .whereType<Map>()
          .map((e) => _SuggestCategory.fromJson(e.cast<String, dynamic>()))
          .toList();
      final pros = (data['establishments'] as List? ?? [])
          .whereType<Map>()
          .map((e) => _Establishment.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _trending = _Trending(cats, pros);
        _trendingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _trendingLoading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Logique de recherche ──────────────────────────────────────────────────

  void _onChanged(String value) {
    setState(() {}); // pour rafraîchir le bouton ✕
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 1) {
      setState(() {
        _suggestions = _Suggestions.empty;
        _lastQuery   = '';
        _loading     = false;
        _errorMsg    = null;
      });
      return;
    }
    // Debounce : on attend que l'utilisateur arrête de taper avant d'appeler
    // l'API. 250 ms = compromis perçu instantané vs trafic réseau.
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSuggest(trimmed);
    });
  }

  Future<void> _runSuggest(String q) async {
    if (q == _lastQuery) return;
    _lastQuery = q;
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final res = await ApiClient.instance.get(
        '/search/suggest',
        params: {'q': q, 'limit': '6'},
      );
      // Si la query a changé pendant l'appel (utilisateur a continué de
      // taper), on ignore cette réponse pour ne pas afficher des résultats
      // périmés.
      if (q != _lastQuery) return;

      final data = res['data'] as Map<String, dynamic>? ?? {};
      final pros = (data['establishments'] as List? ?? [])
          .whereType<Map>()
          .map((e) => _Establishment.fromJson(e.cast<String, dynamic>()))
          .toList();
      final prods = (data['products'] as List? ?? [])
          .whereType<Map>()
          .map((e) => _SuggestProduct.fromJson(e.cast<String, dynamic>()))
          .toList();
      final cats = (data['categories'] as List? ?? [])
          .whereType<Map>()
          .map((e) => _SuggestCategory.fromJson(e.cast<String, dynamic>()))
          .toList();

      setState(() {
        _suggestions = _Suggestions(pros, prods, cats);
        _loading     = false;
      });
    } catch (e) {
      if (q != _lastQuery) return;
      setState(() {
        _loading  = false;
        _errorMsg = e.toString();
      });
    }
  }

  void _setQuery(String q) {
    _ctrl.text      = q;
    _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: q.length));
    _onChanged(q);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    final hasQuery = query.isNotEmpty;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(),
        title: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 16,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Plat, restaurant, boutique, catégorie…',
            border: InputBorder.none, enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintStyle: TextStyle(color: context.textMuted, fontFamily: 'Nunito'),
            contentPadding: EdgeInsets.zero,
            suffixIcon: hasQuery
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: context.textMuted, size: 20),
                    onPressed: () {
                      _ctrl.clear();
                      _onChanged('');
                    })
                : null,
          ),
        ),
      ),
      body: !hasQuery
          ? _TrendingPanel(
              loading: _trendingLoading,
              trending: _trending,
              onPickQuery: _setQuery,
            )
          : _buildResults(context),
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading && _suggestions.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_errorMsg != null && _suggestions.isEmpty) {
      return _ErrorState(message: _errorMsg!, onRetry: () => _runSuggest(_lastQuery));
    }
    if (_suggestions.isEmpty) {
      return _EmptyResults(query: _lastQuery, onPickHint: _setQuery);
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (_loading)
          const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.primary,
              backgroundColor: Colors.transparent),
        // ── Catégories (chips horizontales) ─────────────────────────────────
        if (_suggestions.categories.isNotEmpty) ...[
          _SectionHeader(
              label: 'Catégories', count: _suggestions.categories.length),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _suggestions.categories.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: c.icon != null
                      ? Text(c.icon!, style: const TextStyle(fontSize: 14))
                      : null,
                  label: Text(c.name,
                    style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
                        fontWeight: FontWeight.w700)),
                  onPressed: () => _setQuery(c.name),
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  labelStyle: const TextStyle(color: AppColors.primary),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // ── Établissements ──────────────────────────────────────────────────
        if (_suggestions.establishments.isNotEmpty) ...[
          _SectionHeader(
              label: 'Établissements', count: _suggestions.establishments.length),
          ..._suggestions.establishments.map((p) => _EstablishmentTile(pro: p)),
          const SizedBox(height: 12),
        ],
        // ── Produits ────────────────────────────────────────────────────────
        if (_suggestions.products.isNotEmpty) ...[
          _SectionHeader(
              label: 'Plats / Produits', count: _suggestions.products.length),
          ..._suggestions.products.map((p) => _ProductTile(product: p)),
        ],
      ],
    );
  }
}

// ── Panneau d'idées (avant frappe) — peuplé depuis la BDD ────────────────────

class _TrendingPanel extends StatelessWidget {
  final bool       loading;
  final _Trending  trending;
  final ValueChanged<String> onPickQuery;
  const _TrendingPanel({
    required this.loading,
    required this.trending,
    required this.onPickQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && trending.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }

    final cats = trending.categories;
    final pros = trending.establishments;

    if (cats.isEmpty && pros.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('Tape un mot pour rechercher',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Nunito', fontSize: 15,
                  fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 6),
            Text('Établissements, plats, catégories…',
              style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                  color: context.textMuted)),
          ]),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (cats.isNotEmpty) ...[
          _SectionHeader(label: 'Catégories', count: cats.length),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: cats.map((c) => GestureDetector(
              onTap: () => onPickQuery(c.name),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.borderColor.withOpacity(0.8))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (c.icon != null && c.icon!.isNotEmpty) ...[
                    Text(c.icon!, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                  ],
                  Text(c.name,
                    style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
                        fontWeight: FontWeight.w700, color: context.textPrimary)),
                ]),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (pros.isNotEmpty) ...[
          _SectionHeader(label: 'Populaires', count: pros.length),
          ...pros.map((p) => _EstablishmentTile(pro: p)),
        ],
      ],
    );
  }
}

// ── Header de section ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int    count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Text(label.toUpperCase(),
        style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
            fontWeight: FontWeight.w800, color: context.textMuted,
            letterSpacing: 0.8)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
        child: Text('$count',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 11,
              fontWeight: FontWeight.w800, color: AppColors.primary)),
      ),
    ]),
  );
}

// ── Tuiles ────────────────────────────────────────────────────────────────────

class _EstablishmentTile extends StatelessWidget {
  final _Establishment pro;
  const _EstablishmentTile({required this.pro});

  String get _catLabel => switch (pro.category) {
    'RESTAURANT'  => 'Restaurant',
    'BAKERY'      => 'Boulangerie',
    'GROCERY'     => 'Épicerie',
    'SUPERMARKET' => 'Supermarché',
    'PHARMACY'    => 'Pharmacie',
    _             => pro.category.isEmpty ? '' : pro.category,
  };

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: context.cardColor, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor.withOpacity(0.8))),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (pro.logoUrl ?? pro.coverImageUrl) != null
            ? CachedNetworkImage(
                imageUrl: (pro.logoUrl ?? pro.coverImageUrl)!,
                width: 48, height: 48, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _EmojiBox('🏪'))
            : const _EmojiBox('🏪'),
      ),
      title: Text(pro.businessName,
        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
            fontSize: 15, color: context.textPrimary)),
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
        Expanded(child: Text(
          [_catLabel, if (pro.city != null) pro.city!]
              .where((s) => s.isNotEmpty).join(' • '),
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
              color: context.textMuted), overflow: TextOverflow.ellipsis)),
      ]),
      trailing: Icon(Icons.chevron_right_rounded, color: context.borderColor),
      onTap: () => context.push('/restaurant/${pro.id}'),
    ),
  );
}

class _ProductTile extends StatelessWidget {
  final _SuggestProduct product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: context.cardColor, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.borderColor.withOpacity(0.8))),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: product.imageUrl != null
            ? CachedNetworkImage(
                imageUrl: product.imageUrl!,
                width: 48, height: 48, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const _EmojiBox('🍽️'))
            : const _EmojiBox('🍽️'),
      ),
      title: Text(product.nameFr,
        style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700,
            fontSize: 15, color: context.textPrimary)),
      subtitle: Row(children: [
        Text(
          product.currency == 'XOF'
              ? '${product.price.toStringAsFixed(0)} F'
              : '${product.price.toStringAsFixed(0)} ${product.currency}',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13,
              color: AppColors.primary, fontWeight: FontWeight.w800)),
        const Text(' · ', style: TextStyle(color: Colors.grey)),
        Flexible(child: Text(product.professionalName,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 12,
                color: context.textMuted),
            overflow: TextOverflow.ellipsis)),
      ]),
      trailing: Icon(Icons.chevron_right_rounded, color: context.borderColor),
      onTap: () => context.push('/restaurant/${product.professionalId}'),
    ),
  );
}

class _EmojiBox extends StatelessWidget {
  final String emoji;
  const _EmojiBox(this.emoji);

  @override
  Widget build(BuildContext context) => Container(
    width: 48, height: 48,
    color: AppColors.primary.withOpacity(0.08),
    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))));
}

// ── États ────────────────────────────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final String query;
  final ValueChanged<String> onPickHint;
  const _EmptyResults({required this.query, required this.onPickHint});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🔍', style: TextStyle(fontSize: 56)),
      const SizedBox(height: 14),
      Text('Aucun résultat pour « $query »',
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 17,
            fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 6),
      Text('Essaie un autre mot-clé',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
            color: context.textMuted)),
    ]),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('📡', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text('Recherche indisponible',
        style: TextStyle(fontFamily: 'Nunito', fontSize: 16,
            fontWeight: FontWeight.w800, color: context.textPrimary)),
      const SizedBox(height: 6),
      Text(message,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Nunito', fontSize: 13,
            color: context.textMuted)),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Réessayer'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      ),
    ]),
  );
}
