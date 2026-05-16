// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — AuthProvider central (partagé entre tous les profils)
// Responsabilités :
//   • OTP send / verify
//   • PIN set / verify
//   • Persistance JWT dans SecureStorage
//   • Exposition du rôle → routing dynamique
//   • Logout global
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../constants/app_constants.dart';
import '../../shared/models/app_user.dart';

// ── État d'authentification ───────────────────────────────────────────────────
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final bool isAuthenticated;
  final bool splashDone;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.splashDone = false,
    this.error,
  });

  UserRole? get role => user?.role;
  bool get isPending => user?.status == 'PENDING';

  // C2 — clearError permet de remettre error à null explicitement
  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    bool? isAuthenticated,
    bool? splashDone,
    String? error,
    bool clearError = false,
  }) => AuthState(
    user: user ?? this.user,
    isLoading: isLoading ?? this.isLoading,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    splashDone: splashDone ?? this.splashDone,
    error: clearError ? null : (error ?? this.error),
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  static const _androidOpts = AndroidOptions(encryptedSharedPreferences: true);
  final _storage = const FlutterSecureStorage(aOptions: _androidOpts);
  final _api = ApiClient.instance;

  // M7 — Completer pour synchroniser splash et bootstrap
  final _bootstrapCompleter = Completer<void>();
  Future<void> get bootstrapDone => _bootstrapCompleter.future;

  StreamSubscription? _sessionExpiredSub;

  AuthNotifier() : super(const AuthState()) {
    _bootstrap();
    // Si l'ApiClient détecte un refresh échoué, on bascule en état "déconnecté".
    // Le redirect GoRouter pousse ensuite vers /onboarding.
    _sessionExpiredSub = AuthEvents.onSessionExpired.listen((_) {
      if (state.isAuthenticated) {
        debugPrint('[Auth] Session expirée — logout local');
        state = const AuthState(splashDone: true);
      }
    });
  }

  @override
  void dispose() {
    _sessionExpiredSub?.cancel();
    super.dispose();
  }

  // Chargement initial — restaure la session si JWT valide
  //
  // IMPORTANT : splashDone est mis ICI (dans _bootstrap), pas dans le widget SplashScreen.
  //
  // Pourquoi : GoRouterRefreshStream peut démonter SplashScreen avant que son onComplete()
  // soit appelé (race condition entre bootstrap et le redirect GoRouter), laissant
  // splashDone=false pour toujours → boucle infinie de redirections → page blanche.
  //
  // On attend la durée minimale du splash ET la fin du bootstrap avant de marquer splashDone.
  Future<void> _bootstrap() async {
    state = state.copyWith(isLoading: true);
    await Future.wait([
      _bootstrapImpl()
          .timeout(const Duration(seconds: 3))
          .catchError((e) { debugPrint('[Auth] Bootstrap erreur: $e'); }),
      Future.delayed(const Duration(milliseconds: AppConstants.splashMinDurationMs)),
    ]);
    state = state.copyWith(isLoading: false, splashDone: true);
    if (!_bootstrapCompleter.isCompleted) _bootstrapCompleter.complete();
  }

  Future<void> _bootstrapImpl() async {
    final tokenKey = await _storage.read(key: AppConstants.accessTokenKey);
    final userRaw  = await _storage.read(key: AppConstants.userKey);
    if (tokenKey == null || userRaw == null) return;

    // Restaure la session depuis le stockage local sans appel réseau.
    // Le premier appel API expiration 401 se chargera de déconnecter si besoin.
    final user = AppUser.fromJson(json.decode(userRaw));
    state = state.copyWith(user: user, isAuthenticated: true, isLoading: false);
    debugPrint('[Auth] Session locale restaurée');
  }

  // ── OTP ───────────────────────────────────────────────────────────────────
  Future<({String sessionId, String? otp})> sendOtp(String phone, String countryCode) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/auth/otp/send',
          data: {'phone': phone, 'countryCode': countryCode});
      state = state.copyWith(isLoading: false);
      final data = res['data'] as Map<String, dynamic>;
      // En mode dev, le backend peut renvoyer l'OTP directement dans la réponse
      return (
        sessionId: data['sessionId'] as String,
        otp: data['otp'] as String?,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  // Vérifie l'OTP et renvoie true si c'est un nouvel utilisateur
  Future<bool> verifyOtp({
    required String phone,
    required String code,
    required String sessionId,
    UserRole role = UserRole.client,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/auth/otp/verify', data: {
        'phone': phone,
        'code': code,
        'sessionId': sessionId,
        'role': role.apiValue,
      });
      final data = res['data'];
      await _persistSession(data);
      return data['isNewUser'] ?? false;
    } catch (e) {
      state = state.copyWith(isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  // ── PIN ───────────────────────────────────────────────────────────────────
  // C1 — setPin() retourne UserRole? et gère les erreurs
  Future<UserRole?> setPin(String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/auth/pin/set', data: {'pin': pin});
      await _storage.write(key: AppConstants.pinKey, value: 'true');
      state = state.copyWith(isLoading: false);
      return state.role;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  Future<bool> verifyPin(String phone, String pin) async {
    try {
      final res = await _api.post('/auth/pin/verify',
          data: {'phone': phone, 'pin': pin});
      await _persistSession(res['data']);
      return true;
    } catch (_) { return false; }
  }

  // ── Profil ────────────────────────────────────────────────────────────────
  // C3 — completeProfile() avec try/catch et null guard
  Future<void> completeProfile(Map<String, dynamic> data) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.patch('/users/me', data: data);
      final userData = res['data'] as Map<String, dynamic>?;
      if (userData == null) throw Exception('Réponse serveur incomplète');
      final user = AppUser.fromJson(userData);
      await _storage.write(key: AppConstants.userKey, value: json.encode(user.toJson()));
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  Future<void> refreshProfile() async {
    try {
      final res = await _api.get('/users/me');
      final user = AppUser.fromJson(res['data']);
      await _storage.write(
          key: AppConstants.userKey, value: json.encode(user.toJson()));
      state = state.copyWith(user: user);
    } catch (_) {}
  }

  /// Enregistre le token FCM côté backend.
  /// À appeler après obtention du token Firebase (FirebaseMessaging.getToken).
  Future<void> registerFcmToken(String fcmToken) async {
    try {
      await _api.patch('/users/me/fcm-token', data: {'fcmToken': fcmToken});
      debugPrint('[FCM] Token enregistré (${fcmToken.substring(0, 12)}…)');
    } catch (e) {
      debugPrint('[FCM] Enregistrement échoué: $e');
    }
  }

  // ── Logout global ─────────────────────────────────────────────────────────
  // Pas d'endpoint backend /auth/logout — révocation purement locale.
  // À ajouter côté serveur si on veut invalider le refresh token (blacklist).
  Future<void> logout() async {
    await _api.clearAuth();
    await _storage.deleteAll();
    state = const AuthState(splashDone: true);
  }

  // ── Interne ───────────────────────────────────────────────────────────────
  // C2 — Null guards dans _persistSession()
  Future<void> _persistSession(Map<String, dynamic> data) async {
    final accessToken  = data['accessToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    final userData     = data['user'] as Map<String, dynamic>?;

    if (accessToken == null || refreshToken == null || userData == null) {
      throw Exception('Réponse serveur incomplète (tokens ou user manquants)');
    }

    await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken);
    final user = AppUser.fromJson(userData);
    await _storage.write(key: AppConstants.userKey, value: json.encode(user.toJson()));
    state = state.copyWith(user: user, isAuthenticated: true, isLoading: false, clearError: true);
  }
}

// ── Provider global ───────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier());
