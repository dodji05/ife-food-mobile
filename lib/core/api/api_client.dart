// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Client HTTP centralisé (singleton)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Stream global notifié quand le refresh token a échoué.
/// Le router écoute pour pousser l'utilisateur vers /onboarding.
class AuthEvents {
  static final _ctrl = StreamController<void>.broadcast();
  static Stream<void> get onSessionExpired => _ctrl.stream;
  static void notifySessionExpired() => _ctrl.add(null);
}

class ApiClient {
  static ApiClient? _instance;
  late final Dio _dio;
  late final Dio _refreshDio; // C4 — instance dédiée sans intercepteurs
  static const _androidOpts = AndroidOptions(encryptedSharedPreferences: true);
  final _storage = const FlutterSecureStorage(aOptions: _androidOpts);

  ApiClient._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    // C4 — Dio séparé pour le refresh, sans intercepteurs (évite les boucles)
    _refreshDio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    // Logging en mode debug uniquement.
    // Les bodies des endpoints sensibles (auth) sont MASQUÉS pour éviter de
    // logger PIN/OTP en clair.
    if (kDebugMode) {
      _dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          final isSensitive = options.path.startsWith('/auth/');
          debugPrint('[API] → ${options.method} ${options.path}'
              '${isSensitive ? "  (body masqué)" : "  body=${options.data}"}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          final isSensitive = response.requestOptions.path.startsWith('/auth/');
          debugPrint('[API] ← ${response.statusCode} ${response.requestOptions.path}'
              '${isSensitive ? "  (réponse masquée)" : ""}');
          handler.next(response);
        },
        onError: (e, handler) {
          debugPrint('[API] ✗ ${e.requestOptions.method} ${e.requestOptions.path} → '
              '${e.response?.statusCode ?? e.type}');
          handler.next(e);
        },
      ));
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        // C5 — Flag anti-boucle infinie sur 401
        final isRetry = error.requestOptions.extra['_retry'] == true;
        if (error.response?.statusCode == 401 && !isRetry) {
          error.requestOptions.extra['_retry'] = true;
          final refreshed = await _tryRefresh();
          if (refreshed) {
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final retry = await _dio.fetch(error.requestOptions);
            handler.resolve(retry);
            return;
          }
          // Refresh échoué → session morte. On purge et on notifie le router.
          await clearAuth();
          await _storage.deleteAll();
          AuthEvents.notifySessionExpired();
        }
        handler.next(error);
      },
    ));
  }

  static ApiClient get instance => _instance ??= ApiClient._();

  Future<bool> _tryRefresh() async {
    try {
      final refresh = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refresh == null) return false;
      // C4 — utilise _refreshDio (instance dédiée) au lieu de Dio() inline
      final res = await _refreshDio.post('${AppConstants.baseUrl}/auth/refresh',
          data: {'refreshToken': refresh});
      // C4 — accès sécurisé avec null checks en cascade
      final data = res.data as Map<String, dynamic>?;
      final nested = data?['data'] as Map<String, dynamic>?;
      final accessToken = nested?['accessToken'] as String?;
      if (accessToken == null) return false;
      await _storage.write(key: AppConstants.accessTokenKey, value: accessToken);
      return true;
    } catch (_) { return false; }
  }

  // ── Méthodes HTTP ──────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> get(String path,
      {Map<String, dynamic>? params}) async {
    try {
      final r = await _dio.get(path, queryParameters: params);
      return r.data;
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    try {
      final r = await _dio.post(path, data: data);
      return r.data;
    } on DioException catch (e) { throw _mapError(e); }
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data}) async {
    try {
      final r = await _dio.patch(path, data: data);
      return r.data;
    } on DioException catch (e) { throw _mapError(e); }
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    try {
      final r = await _dio.put(path, data: data);
      return r.data;
    } on DioException catch (e) { throw _mapError(e); }
  }

  Future<Map<String, dynamic>> delete(String path) async {
    try {
      final r = await _dio.delete(path);
      return r.data;
    } on DioException catch (e) { throw _mapError(e); }
  }

  Future<Map<String, dynamic>> postForm(String path, FormData data) async {
    try {
      final r = await _dio.post(path, data: data,
          options: Options(contentType: 'multipart/form-data'));
      return r.data;
    } on DioException catch (e) { throw _mapError(e); }
  }

  // H7 — robuste quelle que soit la forme de data (Map, String, null, autre)
  Exception _mapError(DioException e) {
    final data = e.response?.data;
    String msg;
    if (data is Map) {
      msg = (data['message'] as String?) ?? 'Erreur réseau';
    } else if (data is String && data.isNotEmpty) {
      msg = data;
    } else {
      msg = e.message ?? 'Erreur réseau (${e.response?.statusCode ?? 'inconnue'})';
    }
    return Exception(msg);
  }

  // Perf — suppressions en parallèle avec Future.wait
  Future<void> clearAuth() async {
    await Future.wait([
      _storage.delete(key: AppConstants.accessTokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
    ]);
  }
}
