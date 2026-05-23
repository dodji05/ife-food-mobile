// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Modèle utilisateur unifié (tous profils)
// ─────────────────────────────────────────────────────────────────────────────
import '../../core/constants/app_constants.dart';

class AppUser {
  final String id;
  final String phone;
  final UserRole role;
  final String status;      // ACTIVE | PENDING | SUSPENDED | BANNED
  final String lang;
  final String countryCode;
  final String currency;
  final String? name;
  final String? firstName;
  final String? avatarUrl;
  final String? email;
  final Map<String, dynamic>? professional; // si PROFESSIONAL
  final Map<String, dynamic>? driver;       // si DRIVER
  final bool biometricEnabled;

  const AppUser({
    required this.id,
    required this.phone,
    required this.role,
    required this.status,
    required this.lang,
    required this.countryCode,
    required this.currency,
    this.name,
    this.firstName,
    this.avatarUrl,
    this.email,
    this.professional,
    this.driver,
    this.biometricEnabled = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id:          j['id'] as String,
    phone:       j['phone'] as String,
    role:        UserRoleX.fromApi(j['role'] as String? ?? 'CLIENT'),
    status:      j['status'] as String? ?? 'ACTIVE',
    lang:        j['lang'] as String? ?? 'fr',
    countryCode: j['countryCode'] as String? ?? 'BJ',
    currency:    j['currency'] as String? ?? 'XOF',
    name:        j['name'] as String?,
    firstName:   j['firstName'] as String?,
    avatarUrl:   j['avatarUrl'] as String?,
    email:            j['email'] as String?,
    professional:     j['professional'] as Map<String, dynamic>?,
    driver:           j['driver'] as Map<String, dynamic>?,
    biometricEnabled: j['biometricEnabled'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'phone': phone, 'role': role.apiValue, 'status': status,
    'lang': lang, 'countryCode': countryCode, 'currency': currency,
    'name': name, 'firstName': firstName, 'avatarUrl': avatarUrl,
    'email': email, 'professional': professional, 'driver': driver,
    'biometricEnabled': biometricEnabled,
  };

  String get displayName {
    if (firstName != null && name != null) return '$firstName $name';
    return firstName ?? name ?? phone;
  }

  String get initials {
    if (firstName != null && name != null) {
      return '${firstName![0]}${name![0]}'.toUpperCase();
    }
    return phone.length >= 2 ? phone.substring(phone.length - 2) : '?';
  }

  bool get isActive   => status == 'ACTIVE';
  bool get isPending  => status == 'PENDING';
  bool get isClient   => role == UserRole.client;
  bool get isDriver   => role == UserRole.driver;
  bool get isPro      => role == UserRole.professional;
  bool get isAdmin    => role == UserRole.admin;

  // État métier spécifique livreur
  bool get isDriverOnline => driver?['status'] == 'ONLINE';

  // État métier professionnel
  bool get isProOpen => professional?['isOpen'] == true;
  String? get businessName => professional?['businessName'] as String?;
  String? get proStatus => professional?['status'] as String?;
  bool get isProValidated => proStatus == 'VALIDATED';
}
