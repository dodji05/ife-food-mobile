// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Constantes globales de l'application unifiée
// ─────────────────────────────────────────────────────────────────────────────
class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = String.fromEnvironment(
    'API_URL', defaultValue: 'https://ifeapi.associationireni.org/api/v1');
  static const String wsUrl = String.fromEnvironment(
    'WS_URL', defaultValue: 'https://ifeapi.associationireni.org');

  // Storage keys
  static const String accessTokenKey  = 'ife_access_token';
  static const String refreshTokenKey = 'ife_refresh_token';
  static const String userKey         = 'ife_user';
  static const String themeKey        = 'ife_theme';
  static const String pinKey          = 'ife_pin_set';
  static const String lastPhoneKey    = 'ife_last_phone';
  static const String notifEnabledKey = 'ife_notif_enabled';
  static const String onboardedKey    = 'ife_onboarded';
  static const String homeLayoutKey   = 'ife_home_layout'; // 'v1' | 'v2'

  // Auth
  static const int otpLength          = 6;
  static const int otpValiditySec     = 300; // 5 min
  static const int otpResendSec       = 60;
  static const int otpMaxAttempts     = 3;
  static const int otpBlockMinutes    = 15;
  static const int pinLength          = 4;

  // GPS tracking
  static const int gpsIntervalMs              = 5000; // 5 s
  static const int locationUpdateIntervalMs   = gpsIntervalMs; // alias utilisé par driver_provider

  // Géolocalisation par défaut (Cotonou, Bénin)
  static const double defaultLat = 6.3654;
  static const double defaultLng = 2.4183;

  // Splash
  static const int splashMinDurationMs = 2000;

  // App info
  static const String appName         = 'ifè FOOD';
  static const String appVersion      = '1.0.0';
  static const String supportEmail    = 'gildas31@gmail.com';
  // Format E.164 sans le '+' (utilisé pour wa.me/<phone>).
  // Pour appel direct ou SMS, préfixer '+' au runtime.
  static const String supportWhatsapp = '22990000000'; // TODO: vrai numéro WhatsApp support
  static const String websiteUrl      = 'https://www.ifefood.bj';

  // Nuit auto-theme : 18h UTC → 5h UTC
  static const int darkStartHour      = 18;
  static const int darkEndHour        = 5;
}

// Rôles utilisateur
enum UserRole { client, driver, professional, admin }

extension UserRoleX on UserRole {
  String get apiValue => switch (this) {
    UserRole.client       => 'CLIENT',
    UserRole.driver       => 'DRIVER',
    UserRole.professional => 'PROFESSIONAL',
    UserRole.admin        => 'ADMIN',
  };

  static UserRole fromApi(String v) => switch (v.toUpperCase()) {
    'CLIENT'       => UserRole.client,
    'DRIVER'       => UserRole.driver,
    'PROFESSIONAL' => UserRole.professional,
    'ADMIN'        => UserRole.admin,
    _              => UserRole.client,
  };

  String get label => switch (this) {
    UserRole.client       => 'Client',
    UserRole.driver       => 'Livreur',
    UserRole.professional => 'Professionnel',
    UserRole.admin        => 'Administrateur',
  };

  String get emoji => switch (this) {
    UserRole.client       => '🛒',
    UserRole.driver       => '🛵',
    UserRole.professional => '🏪',
    UserRole.admin        => '⚙️',
  };
}
