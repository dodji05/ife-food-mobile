class User {
  final String id;
  final String phone;
  final String? name;
  final String? firstName;
  final String? email;
  final String? avatarUrl;
  final String role;
  final String status;
  final String lang;
  final String countryCode;
  final String currency;
  final bool biometricEnabled;
  final bool twoFaEnabled;
  final DateTime createdAt;

  const User({
    required this.id, required this.phone, this.name, this.firstName,
    this.email, this.avatarUrl, required this.role, required this.status,
    required this.lang, required this.countryCode, required this.currency,
    this.biometricEnabled = false, this.twoFaEnabled = false, required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'], phone: json['phone'], name: json['name'], firstName: json['firstName'],
    email: json['email'], avatarUrl: json['avatarUrl'], role: json['role'] ?? 'CLIENT',
    status: json['status'] ?? 'ACTIVE', lang: json['lang'] ?? 'fr',
    countryCode: json['countryCode'] ?? 'BJ', currency: json['currency'] ?? 'XOF',
    biometricEnabled: json['biometricEnabled'] ?? false, twoFaEnabled: json['twoFaEnabled'] ?? false,
    createdAt: (DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now()).toLocal(),
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'phone': phone, 'name': name, 'firstName': firstName,
    'email': email, 'avatarUrl': avatarUrl, 'role': role, 'status': status,
    'lang': lang, 'countryCode': countryCode, 'currency': currency,
    'biometricEnabled': biometricEnabled, 'twoFaEnabled': twoFaEnabled,
    'createdAt': createdAt.toIso8601String(),
  };

  String get displayName {
    if (name != null && firstName != null) return '$firstName $name';
    return name ?? firstName ?? phone;
  }
}
