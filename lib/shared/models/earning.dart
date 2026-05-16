class Earning {
  final String id;
  final String type; // DELIVERY_FEE | TIP | BONUS
  final double amount;
  final String currency;
  final String status;
  final String? description;
  final DateTime createdAt;

  const Earning({
    required this.id, required this.type, required this.amount,
    required this.currency, required this.status, this.description, required this.createdAt,
  });

  factory Earning.fromJson(Map<String, dynamic> json) => Earning(
    id: json['id'], type: json['type'] ?? 'DELIVERY_FEE',
    amount: (json['amount'] ?? 0).toDouble(), currency: json['currency'] ?? 'XOF',
    status: json['status'] ?? 'COMPLETED', description: json['description'],
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
  );

  String get typeLabel {
    switch (type) {
      case 'DELIVERY_FEE': return 'Livraison';
      case 'TIP': return 'Pourboire';
      case 'BONUS': return 'Bonus';
      default: return type;
    }
  }

  String get typeEmoji {
    switch (type) {
      case 'DELIVERY_FEE': return '📦';
      case 'TIP': return '🎁';
      case 'BONUS': return '⭐';
      default: return '💰';
    }
  }
}
