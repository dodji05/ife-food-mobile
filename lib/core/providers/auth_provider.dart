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
  final String? accessToken;
  final bool isLoading;
  final bool isAuthenticated;
  final bool splashDone;
  /// True entre `verifyOtp()` réussi et `setPin()` réussi.
  /// Tant que c'est `true`, le redirect force l'utilisateur sur `/auth/pin`.
  /// Repassé à `false` par `setPin()`.
  final bool needsPinSetup;
  /// True si l'utilisateur n'a pas encore de PIN côté backend (`!user.pinHash`).
  final bool isNewUser;
  /// Dernier numéro de téléphone utilisé (E.164). Persiste après logout pour
  /// diriger l'utilisateur de retour vers /login au lieu de /onboarding.
  final String? lastPhone;
  /// True pendant le flow "PIN oublié" (OTP → setPin). Permet au PinScreen
  /// de savoir qu'il doit être en mode "set" même si isNewUser=false.
  final bool forgotPinMode;
  final String? error;

  const AuthState({
    this.user,
    this.accessToken,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.splashDone = false,
    this.needsPinSetup = false,
    this.isNewUser = false,
    this.lastPhone,
    this.forgotPinMode = false,
    this.error,
  });

  UserRole? get role => user?.role;
  bool get isPending => user?.status == 'PENDING';
  /// True si le dernier téléphone utilisé est connu (pour rediriger vers /login).
  bool get hasLastPhone => lastPhone != null && lastPhone!.isNotEmpty;
  /// True si l'utilisateur a complété son identité (prénom renseigné).
  bool get hasProfile => (user?.firstName ?? '').trim().isNotEmpty;

  AuthState copyWith({
    AppUser? user,
    String? accessToken,
    bool? isLoading,
    bool? isAuthenticated,
    bool? splashDone,
    bool? needsPinSetup,
    bool? isNewUser,
    String? lastPhone,
    bool? forgotPinMode,
    String? error,
    bool clearError = false,
  }) => AuthState(
    user: user ?? this.user,
    accessToken: accessToken ?? this.accessToken,
    isLoading: isLoading ?? this.isLoading,
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    splashDone: splashDone ?? this.splashDone,
    needsPinSetup: needsPinSetup ?? this.needsPinSetup,
    isNewUser: isNewUser ?? this.isNewUser,
    lastPhone: lastPhone ?? this.lastPhone,
    forgotPinMode: forgotPinMode ?? this.forgotPinMode,
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
    // Toujours lire le dernier numéro de téléphone (persiste après logout)
    final lastPhone = await _storage.read(key: AppConstants.lastPhoneKey);

    final tokenKey = await _storage.read(key: AppConstants.accessTokenKey);
    final userRaw  = await _storage.read(key: AppConstants.userKey);
    if (tokenKey == null || userRaw == null) {
      // Pas de session active — on préserve lastPhone pour diriger vers /login
      if (lastPhone != null) state = state.copyWith(lastPhone: lastPhone);
      return;
    }

    // Restaure la session depuis le stockage local sans appel réseau.
    final user = AppUser.fromJson(json.decode(userRaw));

    // needsPinSetup dérivé de pinKey pour survivre aux crashs entre
    // verifyOtp() et setPin().
    final pinSet = await _storage.read(key: AppConstants.pinKey);
    final needsPin = pinSet != 'true';

    state = state.copyWith(
      user: user,
      accessToken: tokenKey,
      isAuthenticated: true,
      isLoading: false,
      needsPinSetup: needsPin,
      lastPhone: user.phone.isNotEmpty ? user.phone : lastPhone,
    );
    debugPrint('[Auth] Session restaurée (needsPinSetup=$needsPin, hasProfile=${(user.firstName ?? '').trim().isNotEmpty})');

    if (!needsPin && (user.firstName ?? '').trim().isEmpty) {
      debugPrint('[Auth] firstName manquant — refresh silencieux…');
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
  // setPin() crée ou réinitialise le PIN (modes : nouvelle inscription, reset).
  // Met needsPinSetup:false et forgotPinMode:false → redirect vers dashboard.
  Future<UserRole?> setPin(String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _api.post('/auth/pin/set', data: {'pin': pin});
      await _storage.write(key: AppConstants.pinKey, value: 'true');
      state = state.copyWith(isLoading: false, needsPinSetup: false, forgotPinMode: false);
      return state.role;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return null;
    }
  }

  // verifyPin — connexion directe téléphone+PIN (utilisateurs de retour).
  // needsPinSetup:false → redirect vers le dashboard.
  Future<bool> verifyPin(String phone, String pin) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.post('/auth/pin/verify',
          data: {'phone': phone, 'pin': pin});
      await _persistSession(res['data'] as Map<String, dynamic>, needsPinSetup: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Démarre le flow "PIN oublié" : envoie un OTP et arme forgotPinMode.
  /// Après verifyOtp() + setPin(), forgotPinMode repasse à false.
  Future<({String sessionId, String? otp})> startForgotPin(
      String phone, String countryCode) async {
    state = state.copyWith(forgotPinMode: true, clearError: true);
    return sendOtp(phone, countryCode);
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

  /// Supprime la photo de profil (avatarUrl → null).
  Future<void> deleteAvatar() async {
    await completeProfile({'avatarUrl': null});
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

  /// Persiste le numéro de téléphone comme `lastPhone` sans déclencher d'OTP.
  /// Utilisé par le flow "J'ai déjà un compte" (onboarding → phone → PIN).
  Future<void> savePhone(String phone, String countryCode) async {
    await _storage.write(key: AppConstants.lastPhoneKey, value: phone);
    state = state.copyWith(lastPhone: phone);
  }

  // ── Logout global ─────────────────────────────────────────────────────────
  // lastPhone est PRÉSERVÉ après logout pour diriger l'utilisateur vers
  // /login (téléphone+PIN) plutôt que vers /onboarding.
  Future<void> logout() async {
    final lastPhone = state.user?.phone.isNotEmpty == true
        ? state.user!.phone
        : state.lastPhone;
    await _api.clearAuth();
    await _storage.deleteAll();
    // Re-écriture du dernier téléphone pour la prochaine ouverture
    if (lastPhone != null && lastPhone.isNotEmpty) {
      await _storage.write(key: AppConstants.lastPhoneKey, value: lastPhone);
    }
    state = AuthState(splashDone: true, lastPhone: lastPhone);
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
    // Si le PIN est déjà configuré, on le marque dans le stockage pour que
    // _bootstrapImpl le retrouve au prochain démarrage (évite la redirection
    // vers /auth/pin alors que l'utilisateur a déjà un PIN).
    if (needsPinSetup == false) {
      await _storage.write(key: AppConstants.pinKey, value: 'true');
    }
    // Persiste le dernier téléphone pour survivre au logout
    if (user.phone.isNotEmpty) {
      await _storage.write(key: AppConstants.lastPhoneKey, value: user.phone);
    }
    state = state.copyWith(
      user: user,
      accessToken: accessToken,
      isAuthenticated: true,
      isLoading: false,
      needsPinSetup: needsPinSetup,
      isNewUser: isNewUser,
      lastPhone: user.phone.isNotEmpty ? user.phone : state.lastPhone,
      clearError: true,
    );
  }
}

// ── Provider global ───────────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
    (ref) => AuthNotifier());
