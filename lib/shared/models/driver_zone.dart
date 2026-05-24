class DeliveryZone {
  final String id;
  final String name;
  final String country;
  final String? fromCity;
  final String? toCity;
  final double baseFee;
  final String currency;
  final bool isActive;
  final bool selected;

  const DeliveryZone({
    required this.id,
    required this.name,
    required this.country,
    this.fromCity,
    this.toCity,
    required this.baseFee,
    required this.currency,
    required this.isActive,
    this.selected = false,
  });

  factory DeliveryZone.fromJson(Map<String, dynamic> j) => DeliveryZone(
    id:       j['id']       as String,
    name:     j['name']     as String,
    country:  j['country']  as String? ?? 'BJ',
    fromCity: j['fromCity'] as String?,
    toCity:   j['toCity']   as String?,
    baseFee:  (j['baseFee'] as num).toDouble(),
    currency: j['currency'] as String? ?? 'XOF',
    isActive: j['isActive'] as bool? ?? true,
    selected: j['selected'] as bool? ?? false,
  );
}
