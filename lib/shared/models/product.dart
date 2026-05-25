// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle Product
// Correspond à la réponse de GET /products et GET /professionals/:id/products
//
// ⚠️ Modèle UNIFIÉ : merge des champs historiques (name/description String
// pré-extraits en français + categoryId getter) avec les champs multilingues
// natifs de l'API standalone (nameMap, descriptionMap, stock, currency,
// vraie catégorie nullable). Tous les nouveaux champs sont rétrocompatibles
// (defaults sensibles) — zéro régression côté consumers existants.
// ─────────────────────────────────────────────────────────────────────────────

class Product {
  // ── Identité ──────────────────────────────────────────────────────────────
  final String  id;
  final String  professionalId;
  final String? categoryId;      // ID de catégorie (peut être null si flat)

  // ── Multilingue ───────────────────────────────────────────────────────────
  /// Nom pré-extrait en français (ou langue fallback). Conservé pour
  /// rétro-compatibilité avec les écrans qui font `product.name` directement.
  final String  name;

  /// Description pré-extraite en français. Idem rétro-compat.
  final String? description;

  /// Map multilingue brute `{fr: ..., en: ..., es: ...}` retournée par l'API.
  /// Utilisée par `localizedName(locale)` pour le vrai i18n runtime.
  final Map<String, String> nameMap;

  /// Map multilingue brute pour la description. `null` si pas de description.
  final Map<String, String>? descriptionMap;

  // ── Catalogue ─────────────────────────────────────────────────────────────
  final double  price;
  /// Devise. Défaut `XOF` (Franc CFA Bénin). Override possible par produit.
  final String  currency;
  final String? imageUrl;
  final bool    isAvailable;
  /// Stock disponible. `null` = stock illimité / non géré pour ce produit.
  final int?    stock;
  final int?    preparationTimeMin;

  /// Variantes de prix : `[{name: 'Grand', price: 3500}, …]`
  final List<Map<String, dynamic>> variants;
  /// Options / extras : `[{name: 'Sauce pimentée', price: 0, required: false}, …]`
  final List<Map<String, dynamic>> options;

  const Product({
    required this.id,
    required this.professionalId,
    this.categoryId,
    required this.name,
    this.description,
    Map<String, String>? nameMap,
    this.descriptionMap,
    required this.price,
    this.currency = 'XOF',
    this.imageUrl,
    this.isAvailable = true,
    this.stock,
    this.preparationTimeMin,
    this.variants = const [],
    this.options  = const [],
  }) : nameMap = nameMap ?? const {};

  factory Product.fromJson(Map<String, dynamic> j) {
    // Backend Prisma : name et description sont Json multilingue {fr, en}.
    // On garde le pré-extrait pour rétro-compat ET on conserve la Map brute
    // pour le vrai i18n via localizedName(locale).
    Map<String, String> _toMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      if (raw is String && raw.isNotEmpty) {
        // Rétro-compat : l'ancien backend pouvait renvoyer juste une String.
        return {'fr': raw};
      }
      return const {};
    }
    String _firstFr(Map<String, String> m, [String fallback = '']) =>
        m['fr'] ?? m['en'] ?? (m.isNotEmpty ? m.values.first : fallback);

    // Catégorie : peut être un id string, ou une relation incluse {id, name, …},
    // ou un champ `categoryId` séparé. On extrait l'id de tous les cas.
    String? _categoryId() {
      final raw = j['category'];
      if (raw is String) return raw.isEmpty ? null : raw;
      if (raw is Map)    return (raw['id'] as String?);
      final cid = j['categoryId'] as String?;
      return (cid != null && cid.isEmpty) ? null : cid;
    }

    final nameMap        = _toMap(j['name']);
    final descMap        = j['description'] == null ? null : _toMap(j['description']);

    return Product(
      id:                  j['id']             as String? ?? '',
      professionalId:      j['professionalId'] as String? ?? '',
      categoryId:          _categoryId(),
      name:                _firstFr(nameMap),
      description:         descMap == null ? null : _firstFr(descMap, ''),
      nameMap:             nameMap,
      descriptionMap:      (descMap != null && descMap.isNotEmpty) ? descMap : null,
      price:               (j['price']        as num?)?.toDouble() ?? 0.0,
      currency:            j['currency']      as String? ?? 'XOF',
      imageUrl:            j['imageUrl']      as String?,
      isAvailable:         j['isAvailable']   as bool?   ?? true,
      stock:               (j['stock']         as num?)?.toInt(),
      preparationTimeMin:  (j['preparationTimeMin'] as num?)?.toInt(),
      variants: (j['variants'] is List
          ? (j['variants'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[]),
      options: (j['options'] is List
          ? (j['options'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : const <Map<String, dynamic>>[]),
    );
  }

  Map<String, dynamic> toJson() {
    // Local pour contourner la règle Dart 3 de non-promotion des public fields :
    // `description` étant un final public, le compilateur refuse la promotion
    // de `String?` -> `String` même après un null-check dans une expression.
    final desc = description;
    return {
      'id':                 id,
      'professionalId':     professionalId,
      'categoryId':         categoryId,
      // On envoie la Map multilingue complète si présente, sinon repli sur
      // la String pré-extraite (utile pour les cas d'édition rapide).
      'name':               nameMap.isNotEmpty ? nameMap : {'fr': name},
      'description':        descriptionMap ?? (desc != null ? {'fr': desc} : null),
      'price':              price,
      'currency':           currency,
      'imageUrl':           imageUrl,
      'isAvailable':        isAvailable,
      'stock':              stock,
      'preparationTimeMin': preparationTimeMin,
      if (variants.isNotEmpty) 'variants': variants,
      if (options.isNotEmpty)  'options':  options,
    };
  }

  // ── Helpers d'affichage ───────────────────────────────────────────────────
  String get formattedPrice {
    final p = price.toStringAsFixed(0);
    return currency == 'XOF' ? '$p F' : '$p $currency';
  }

  /// Alias historique : certains écrans utilisent `product.categoryId` quand
  /// d'autres utilisent `product.category`. On expose les deux.
  String get category => categoryId ?? '';

  /// `true` si le stock est géré ET ≤ 0. Utile pour griser un produit côté UI.
  bool get isOutOfStock => stock != null && stock! <= 0;

  // ── i18n ──────────────────────────────────────────────────────────────────
  /// Récupère le nom dans la locale demandée, avec fallback intelligent :
  /// `locale → fr → en → première valeur dispo → String pré-extraite`.
  String localizedName(String locale) =>
      nameMap[locale]
      ?? nameMap['fr']
      ?? nameMap['en']
      ?? (nameMap.isNotEmpty ? nameMap.values.first : name);

  /// Idem pour la description. Retourne `null` si vraiment rien n'est dispo.
  String? localizedDescription(String locale) {
    if (descriptionMap != null) {
      return descriptionMap![locale]
          ?? descriptionMap!['fr']
          ?? descriptionMap!['en']
          ?? (descriptionMap!.isNotEmpty ? descriptionMap!.values.first : description);
    }
    return description;
  }

  // ── copyWith — sentinel pour fields nullable effaçables ───────────────────
  static const _keep = Object();

  Product copyWith({
    String? name,
    Object? description           = _keep,
    Map<String, String>? nameMap,
    Object? descriptionMap        = _keep,
    double? price,
    String? currency,
    Object? imageUrl              = _keep,
    Object? categoryId            = _keep,
    bool?   isAvailable,
    Object? stock                 = _keep,
    Object? preparationTimeMin    = _keep,
    List<Map<String, dynamic>>? variants,
    List<Map<String, dynamic>>? options,
  }) => Product(
    id:                 id,
    professionalId:     professionalId,
    categoryId:         categoryId      == _keep ? this.categoryId      : categoryId      as String?,
    name:               name            ?? this.name,
    description:        description     == _keep ? this.description     : description     as String?,
    nameMap:            nameMap         ?? this.nameMap,
    descriptionMap:     descriptionMap  == _keep ? this.descriptionMap  : descriptionMap  as Map<String, String>?,
    price:              price           ?? this.price,
    currency:           currency        ?? this.currency,
    imageUrl:           imageUrl        == _keep ? this.imageUrl        : imageUrl        as String?,
    isAvailable:        isAvailable     ?? this.isAvailable,
    stock:              stock           == _keep ? this.stock           : stock           as int?,
    preparationTimeMin: preparationTimeMin == _keep
        ? this.preparationTimeMin
        : preparationTimeMin as int?,
    variants:           variants        ?? this.variants,
    options:            options         ?? this.options,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ProductCategory — Catégorie de produits propre à un pro
// Correspond à GET /products/categories/:professionalId
// ─────────────────────────────────────────────────────────────────────────────
class ProductCategory {
  final String  id;
  final String  professionalId;
  /// Nom multilingue `{fr: 'Entrées', en: 'Starters', …}`.
  final Map<String, String> name;
  /// Emoji ou identifiant d'icône (ex: `🥗`, `salad`).
  final String? icon;
  /// Ordre d'affichage (croissant). Défaut 0.
  final int     sortOrder;

  const ProductCategory({
    required this.id,
    required this.professionalId,
    required this.name,
    this.icon,
    this.sortOrder = 0,
  });

  factory ProductCategory.fromJson(Map<String, dynamic> j) {
    Map<String, String> toMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      if (raw is String && raw.isNotEmpty) return {'fr': raw};
      return const {};
    }
    return ProductCategory(
      id:             j['id']             as String? ?? '',
      professionalId: j['professionalId'] as String? ?? '',
      name:           toMap(j['name']),
      icon:           j['icon']           as String?,
      sortOrder:      (j['sortOrder']      as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':             id,
    'professionalId': professionalId,
    'name':           name,
    'icon':           icon,
    'sortOrder':      sortOrder,
  };

  /// Nom localisé avec fallback fr → en → première valeur → `'Catégorie'`.
  String localizedName(String locale) =>
      name[locale] ?? name['fr'] ?? name['en']
      ?? (name.isNotEmpty ? name.values.first : 'Catégorie');
}
