// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle Product
// Correspond à la réponse de GET /products et GET /professionals/:id/products
// ─────────────────────────────────────────────────────────────────────────────

class Product {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final String professionalId;
  final int? preparationTimeMin;

  const Product({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    required this.isAvailable,
    required this.professionalId,
    this.preparationTimeMin,
  });

  factory Product.fromJson(Map<String, dynamic> j) {
    // Backend Prisma : name et description sont Json multilingue {fr, en}.
    // On extrait fr en priorité, sinon en, sinon string brute (rétrocompat).
    String _str(dynamic raw) {
      if (raw == null) return '';
      if (raw is String) return raw;
      if (raw is Map) return (raw['fr'] ?? raw['en'] ?? raw.values.first ?? '').toString();
      return raw.toString();
    }
    // Catégorie : peut être un id string, ou une relation incluse {id, name, ...}.
    String _category() {
      final raw = j['category'];
      if (raw is String) return raw;
      if (raw is Map) return (raw['id'] as String?) ?? '';
      return (j['categoryId'] as String?) ?? '';
    }
    return Product(
      id:                  j['id'] as String? ?? '',
      name:                _str(j['name']),
      description:         j['description'] == null ? null : _str(j['description']),
      price:               (j['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl:            j['imageUrl'] as String?,
      category:            _category(),
      isAvailable:         j['isAvailable'] as bool? ?? true,
      professionalId:      j['professionalId'] as String? ?? '',
      preparationTimeMin:  (j['preparationTimeMin'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'category': category,
    'isAvailable': isAvailable,
    'professionalId': professionalId,
    'preparationTimeMin': preparationTimeMin,
  };

  String get formattedPrice => '${price.toStringAsFixed(0)} F';

  // Alias pour compatibilité avec les écrans
  String get categoryId => category;

  // Support i18n basique : `name` et `description` peuvent être des Maps JSON
  String localizedName(String locale) => name;
  String? localizedDescription(String locale) => description;

  // FIX: Object? sentinel pour les champs nullable effaçables
  static const _keep = Object();

  Product copyWith({
    String? name,
    Object? description     = _keep,
    double? price,
    Object? imageUrl        = _keep,
    String? category,
    bool? isAvailable,
    Object? preparationTimeMin = _keep,
  }) => Product(
    id: id,
    name:               name            ?? this.name,
    description:        description     == _keep ? this.description     : description     as String?,
    price:              price           ?? this.price,
    imageUrl:           imageUrl        == _keep ? this.imageUrl        : imageUrl        as String?,
    category:           category        ?? this.category,
    isAvailable:        isAvailable     ?? this.isAvailable,
    professionalId:     professionalId,
    preparationTimeMin: preparationTimeMin == _keep
        ? this.preparationTimeMin
        : preparationTimeMin as int?,
  );
}
