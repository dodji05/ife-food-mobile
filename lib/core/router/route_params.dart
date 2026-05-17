// ─────────────────────────────────────────────────────────────────────────────
// route_params.dart — paramètres typés pour les routes GoRouter
//
// Pourquoi : `state.extra` est typé `Object?`. Sans contrat, chaque builder
// faisait `extra as Map<String, dynamic>?` puis `extra['phone'] as String`,
// avec risque de crash sur :
//   • deep links sans extra
//   • hot reload qui réinitialise les extras
//   • navigation depuis une notification push
//   • erreur de frappe sur la clé
//
// Solution : une classe `XxxRouteParams` par route paramétrée. Le compilateur
// garantit les champs au call site (context.push), et le builder reçoit un
// objet déjà typé — plus de cast manuel.
// ─────────────────────────────────────────────────────────────────────────────
import '../constants/app_constants.dart';

/// Paramètres de la route `/auth/otp`.
/// Construits par `phone_screen.dart` après l'appel à `sendOtp`.
class OtpRouteParams {
  /// Numéro complet au format E.164 (ex: +22997111001).
  final String phone;

  /// Identifiant de session OTP retourné par le backend.
  final String sessionId;

  /// Code ISO 3166-1 alpha-2 du pays sélectionné (ex: BJ, CI, SN).
  final String countryCode;

  /// Rôle pour lequel l'utilisateur s'inscrit/se connecte.
  final UserRole role;

  /// Code OTP renvoyé par le backend en mode dev/test pour auto-remplissage.
  /// `null` en production — l'utilisateur saisit manuellement.
  final String? prefillOtp;

  const OtpRouteParams({
    required this.phone,
    required this.sessionId,
    this.countryCode = 'BJ',
    this.role = UserRole.client,
    this.prefillOtp,
  });
}

/// Paramètres de la route `/auth/pin`.
///
/// Tous les champs sont OPTIONNELS car la source de vérité est `AuthState` :
///   • `isNewUser` détermine le mode (set vs login)
///   • `user.phone` fournit le téléphone
///
/// Ces paramètres servent uniquement pour :
///   • Changer son PIN depuis le profil (mode='set' forcé sans passer par OTP)
///   • Tests / deep links
class PinRouteParams {
  /// `'set'` (création + confirm) ou `'login'` (saisie simple).
  /// Si null → dérivé de `AuthState.isNewUser`.
  final String? mode;

  /// Numéro complet au format E.164.
  /// Si null → dérivé de `AuthState.user.phone`.
  final String? phone;

  const PinRouteParams({this.mode, this.phone});
}

/// Paramètres de la route `/navigate` (navigation GPS externe).
/// Utilisée par l'écran de mission pour ouvrir Maps/Waze.
class NavigateRouteParams {
  /// Latitude de la destination.
  final double lat;

  /// Longitude de la destination.
  final double lng;

  /// Libellé affiché dans l'en-tête (nom du restaurant, adresse client…).
  final String label;

  const NavigateRouteParams({
    required this.lat,
    required this.lng,
    this.label = 'Destination',
  });
}
