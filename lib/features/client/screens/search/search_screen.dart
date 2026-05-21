import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/professional.dart';
import '../../../../shared/models/product.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Professional> _pros = [];
  List<Product> _products = [];
  bool _loading = false;
  String _lastQuery = '';

  Future<void> _search(String q) async {
    if (q.trim() == _lastQuery || q.trim().length < 2) return;
    _lastQuery = q.trim();
    setState(() => _loading = true);

    try {
      final [prosRes, productsRes] = await Future.wait([
        ApiClient.instance.get('/geo/nearby', params: {'lat': 6.3654, 'lng': 2.4183, 'radius': 20}),
        ApiClient.instance.get('/products/search', params: {'q': q}),
      ]);

      // /geo/nearby returns array directly; /products/search returns { data: [...] }
      List unwrap(Map<String, dynamic> r) {
        final raw = r['data'];
        return raw is List ? raw : (raw is Map ? (raw['data'] as List? ?? []) : []);
      }
      final allPros = unwrap(prosRes).map((e) => Professional.fromJson(e as Map<String, dynamic>)).toList();
      final filteredPros = allPros.where((p) => p.businessName.toLowerCase().contains(q.toLowerCase())).toList();
      final prods = unwrap(productsRes).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();

      setState(() { _pros = filteredPros; _products = prods; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.offWhite,
    appBar: AppBar(
      title: TextField(
        controller: _ctrl, autofocus: true,
        onChanged: _search,
        style: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w600),
        decoration: const InputDecoration(
          hintText: 'Plat, restaurant, produit…', border: InputBorder.none,
          enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          hintStyle: TextStyle(color: AppColors.grey, fontFamily: 'Nunito'),
        ),
      ),
      leading: const BackButton(),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
      : _ctrl.text.length < 2
        ? _suggestions()
        : ListView(padding: const EdgeInsets.all(16), children: [
            if (_pros.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Établissements',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey, letterSpacing: 0.5))),
              ..._pros.map((p) => ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: p.coverImageUrl != null
                    ? CachedNetworkImage(imageUrl: p.coverImageUrl!, width: 48, height: 48, fit: BoxFit.cover)
                    : Container(width: 48, height: 48, color: AppColors.primary.withOpacity(0.1), child: Center(child: Text(p.categoryEmoji, style: const TextStyle(fontSize: 24))))),
                title: Text(p.businessName, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text(p.city ?? '', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.grey)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.lightGrey),
                onTap: () => context.push('/restaurant/${p.id}'),
              )),
              const SizedBox(height: 16),
            ],
            if (_products.isNotEmpty) ...[
              const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Produits',
                style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey, letterSpacing: 0.5))),
              ..._products.map((p) => ListTile(
                leading: ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: p.imageUrl != null
                    ? CachedNetworkImage(imageUrl: p.imageUrl!, width: 48, height: 48, fit: BoxFit.cover)
                    : Container(width: 48, height: 48, color: AppColors.yellow.withOpacity(0.2), child: const Center(child: Text('🍽️', style: TextStyle(fontSize: 24))))),
                title: Text(p.localizedName('fr'), style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 15)),
                subtitle: Text('${p.price.toStringAsFixed(0)} F', style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.lightGrey),
                onTap: () {},
              )),
            ],
            if (_pros.isEmpty && _products.isEmpty && _ctrl.text.length >= 2)
              const Center(child: Padding(
                padding: EdgeInsets.all(40),
                child: Column(children: [
                  Text('🔍', style: TextStyle(fontSize: 48)),
                  SizedBox(height: 12),
                  Text('Aucun résultat', style: TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.nearBlack)),
                  SizedBox(height: 8),
                  Text('Essayez avec un autre mot-clé', style: TextStyle(fontFamily: 'Nunito', fontSize: 14, color: AppColors.grey), textAlign: TextAlign.center),
                ]),
              )),
          ]),
  );

  Widget _suggestions() => ListView(padding: const EdgeInsets.all(16), children: [
    const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Suggestions',
      style: TextStyle(fontFamily: 'Nunito', fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.grey, letterSpacing: 0.5))),
    ...[
      ('🍕', 'Pizza'), ('🍔', 'Burger'), ('🍜', 'Riz'), ('🥗', 'Salade'),
      ('🥖', 'Pain'), ('🍣', 'Poisson'), ('🍗', 'Poulet'), ('🥤', 'Boisson'),
    ].map((item) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.lightGrey.withOpacity(0.8))),
      child: ListTile(
        leading: Text(item.$1, style: const TextStyle(fontSize: 22)),
        title: Text(item.$2, style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.north_west_rounded, size: 16, color: AppColors.grey),
        onTap: () { _ctrl.text = item.$2; _search(item.$2); },
      ),
    )).toList(),
  ]);
}
