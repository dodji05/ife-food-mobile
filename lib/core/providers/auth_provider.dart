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
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../api/api_client.dart';
import '../constants/app_constants.dart';
import '../../shared/models/app_user.dart';

// ── État d'authentification ───────────────────────────────────────────────────
//
// Machine à états de l'auth flow. Le GoRouter redirect est la SEULE source
// de vérité pour la navigation post-action — les écrans ne font plus de
// context.go() après verifyOtp / setPin / completeProfile. Ils muent l'état,
// le redirect réévalue et pousse l'écran suivant.
//
// Cycle de vie typique (nouvel utilisateur) :
//
//   /onboarding            { isAuth: false, needsPinSetup: false, hasProfile: false }
//   /auth/phone            idem
//   /auth/otp              idem
//   verifyOtp() succès →   { isAuth: TRUE,  needsPinSetup: TRUE,  hasProfile: false }
//                          → redirect pousse vers /auth/pin
//   setPin() succès →      { isAuth: true,  needsPinSetup: FALSE, hasProfile: false }
//                          → redirect pousse vers /auth/complete-profile
//   completeProfile() →    { isAuth: true,  needsPinSetup: false, hasProfile: TRUE  }
//                          → redirect pousse vers /home (ou dashboard du rôle)
// ─────────────────────────────────────────────────────────────────────────────
class AuthState {
  final AppUser? user;
  final bool isLoading;
  final bool isAuthenticated;
  final bool splashDone;
  /// True entre `verifyOtp()` réussi et `setPin()`/`verifyPin()` réussi.
  /// Tant que c'est `true`, le redirect force l'utilisateur sur `/auth/pin`,
  /// peu importe d'où il essaie de naviguer.
  ///
  /// Le nom couvre les 2 cas selon `isNewUser` :
  ///   • nouveau compte → l'écran PIN est en mode "set" (création + confirm)
  ///   • compte existant → l'écran PIN est en mode "login" (saisie simple)
  ///
  /// Repassé à `false` par `setPin()` ou `verifyPin()` réussi.
  final bool needsPinSetup;
  /// True si l'utilisateur n'a pas encore de PIN côté backend (`!user.pinHash`).
  /// Détermine le mode du PinScreen : `'set'` (création) vs `'login'` (saisie).
  /// Renvoyé par `verifyOtp` comme `isNewUser`.
  final bool isNewUser;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.splashDone = false,
    this.needsPinSetup = false,
    this.isNewUser = false,
    this.error,
  });

  UserRole? get role => user?.role;
  bool get isPending => user?.status == 'PENDING';
  /// True si l'utilisateur a complété son identité (prénom renseigné).
  /// Utilisé par le redirect pour décider entre `/auth/complete-profile`
  /// et le dashboard.
  bool get hasProfile => (user?.firstName ?? '').trim().isNotEmpty;

  // C2 — clearError permet de remettre error à null explicitement
  AuthState copyWith({
    AppUser? user,
    bool? isLoading,
    bool? isAuthenticated,
    bool? splashDone,
    bool? needsPinSetup,
    bool? isNewUser,
    String? error,
    bool clearError = false,
  }) => AuthState(
    user: user ?? this.user,
    isLoading: isLoading ?? this.isLoading,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    splashDone: splashDone ?? this.splashDone,
    needsPinSetup: needsPinSetup ?? this.needsPinSetup,
    isNewUser: isNewUser ?? this.isNewUser,
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

    // CRITIQUE — needsPinSetup doit être dérivé de la persistence pour
    // éviter qu'un crash entre verifyOtp() et setPin() laisse l'utilisateur
    // avec un token valide mais sans PIN backend. pinKey est mis à 'true'
    // par setPin() une fois l'API serveur appelée avec succès.
    final pinSet = await _storage.read(key: AppConstants.pinKey);
    final needsPin = pinSet != 'true';

    state = state.copyWith(
      user: user,
      isAuthenticated: true,
      isLoading: false,
      needsPinSetup: needsPin,
    );
    debugPrint('[Auth] Session locale restaurée (needsPinSetup=$needsPin, hasProfile=${(user.firstName ?? '').trim().isNotEmpty})');

    // Si firstName est absent du cache local, on rafraîchit depuis /users/me
    // avant que le router décide du routage (évite un redirect inutile vers
    // /auth/complete-profile pour un compte déjà complet côté serveur).
    if (!needsPin && (user.firstName ?? '').trim().isEmpty) {
      debugPrint('[Auth] firstName manquant en cache — refresh silencieux…');
      await refreshProfile();
    }
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

  // Vérifie l'OTP, persiste la session ET arme `needsPinSetup:true`.
  // Le redirect GoRouter (source unique de vérité) pousse ensuite vers /auth/pin.
  // Renvoie isNewUser pour info — la navigation ne s'appuie PAS dessus.
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
      final data = res['data'] as Map<String, dynamic>;
      final isNew = data['isNewUser'] as bool? ?? false;
      // _persistSession set isAuthenticated:true et persiste tokens/user.
      // On lui passe les flags du flow d'auth pour qu'ils soient inclus dans
      // la même mutation atomique → un seul fire du GoRouterRefreshStream.
      await _persistSession(data, needsPinSetup: true, isNewUser: isNew);
      return isNew;
    } catch (e) {
      state = state.copyWith(isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
  }

  // ── PIN ───────────────────────────────────────────────────────────────────
  // C1 — setPin() retourne UserRole? et gère les erreurs.
  // Met `needsPinSetup: false` → le redirect bascule vers /auth/complete-profile
  // (si pas de prénom) ou directement le dashboard.
  Future<UserRole?> setPin(String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/auth/pin/set', data: {'pin': pin});
      await _storage.write(key: AppConstants.pinKey, value: 'true');
      state = state.copyWith(isLoading: false, needsPinSetup: false);
      return state.role;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  // verifyPin (mode login). Idem : fixe `needsPinSetup:false`, le redirect
  // gère la navigation suivante (dashboard du rôle si profil complet).
  Future<bool> verifyPin(String phone, String pin) async {
    try {
      final res = await _api.post('/auth/pin/verify',
          data: {'phone': phone, 'pin': pin});
      await _persistSession(res['data'] as Map<String, dynamic>, needsPinSetup: false);
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

  /// Upload + assigne un nouvel avatar pour l'utilisateur courant.
  /// Flow en 2 temps :
  ///   1. POST /uploads/avatar (multipart 'file') -> URL Cloudinary
  ///   2. PATCH /users/me {avatarUrl} -> persistance + refresh state
  /// Le mobile cible : client + driver + pro (chacun depuis son profil).
  Future<void> uploadAvatar(File imageFile) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // 1) Upload
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });
      final upload = await _api.postForm('/uploads/avatar', form);
      final data = upload['data'];
      String? url;
      if (data is String) url = data;
      if (data is Map<String, dynamic>) {
        url = (data['url'] ?? data['imageUrl']) as String?;
      }
      if (url == null || url.isEmpty) {
        throw Exception('Upload échoué : URL vide');
      }
      // 2) Patch user + refresh state (réutilise completeProfile générique)
      await completeProfile({'avatarUrl': url});
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      rethrow;
    }
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
  //
  // [needsPinSetup] / [isNewUser] : flags du flow d'auth, transmis ici pour
  // qu'ils soient appliqués dans la MÊME mutation d'état que isAuthenticated.
  // Sinon on aurait 2 fires séparés du GoRouterRefreshStream et le redirect
  // évaluerait un état intermédiaire incohérent.
  Future<void> _persistSession(
    Map<String, dynamic> data, {
    bool? needsPinSetup,
    bool? isNewUser,
  }) async {
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
    state = state.copyWith(
      user: user,
      isAuthenticated: true,
      isLoading: false,
      needsPinSetup: needsPinSetup,
      isNewUser: isNewUser,
      clearError: true,
    );
  }
}

// ── Provider global ───────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier());
