// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Service Firebase Cloud Messaging (FCM)
//
// Responsabilités :
//   1. Demander la permission notif (iOS + Android 13+)
//   2. Récupérer le token FCM et l'envoyer au backend via authProvider
//      (PATCH /users/me/fcm-token) — auto-refresh sur onTokenRefresh
//   3. Créer le channel Android 'ife_orders' (requis pour Android 8+ +
//      cohérent avec le payload backend android.notification.channel_id)
//   4. Foreground handler : afficher la notif via flutter_local_notifications
//      (FCM ne le fait PAS automatiquement quand l'app est au premier plan)
//   5. Tap handler : naviguer vers /pro/order/:id, /order/:id ou
//      /driver/active-mission selon le rôle de l'utilisateur authentifié
//
// Cycle de vie :
//   • init(ref) appelé UNE FOIS depuis main.dart après runApp.
//   • Écoute authProvider : à chaque login, ré-enregistre le token (utile si
//     l'utilisateur change de compte sur le même device — chaque user doit
//     avoir son propre token côté backend pour recevoir les bonnes notifs).
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_client.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../router/app_router.dart';
import '../../features/driver/providers/driver_provider.dart';
import '../../shared/models/mission.dart';

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Channel ID Android — DOIT matcher la valeur envoyée par le backend dans
  /// `android.notification.channel_id` (cf. notifications.service.ts).
  static const _orderChannelId = 'ife_orders';
  static const _orderChannelName = 'Commandes ifè FOOD';
  static const _orderChannelDesc =
      'Notifications de nouvelles commandes, livraisons et statuts.';

  /// Point d'entrée — à appeler depuis main.dart après runApp.
  /// Idempotent : appels multiples sans effet (utile en hot-reload).
  static Future<void> init(Ref ref) async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _requestPermission();
      await _initLocalNotifications();
      _wireForegroundListener();
      _wireTokenRefreshListener(ref);
      _wireTapListeners(ref);

      // Écoute chaque changement de l'auth state.
      // On ne filtre PAS sur la transition prev→next pour éviter la race
      // condition entre FcmService.init() (build frame 0) et _bootstrapImpl()
      // (post-frame callback) : si _bootstrapImpl se termine avant que le
      // listener soit en place, la transition est ratée et le token n'est
      // jamais enregistré.
      // L'appel est idempotent (PATCH /users/me/fcm-token), le léger surplus
      // de requêtes est négligeable.
      ref.listen(authProvider, (prev, next) {
        if (next.isAuthenticated) {
          _registerCurrentToken(ref);
        }
      });

      // Tente aussi immédiatement si l'utilisateur est déjà authentifié
      // (session persistée depuis la dernière ouverture).
      final alreadyAuth = ref.read(authProvider).isAuthenticated;
      if (alreadyAuth) {
        await _registerCurrentToken(ref);
      }
    } catch (e, st) {
      debugPrint('[FCM] init failed: $e\n$st');
    }
  }

  // ── 1. Permission utilisateur ──────────────────────────────────────────────
  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus.name}');
  }

  // ── 2. Local notifications + channel Android ──────────────────────────────
  static Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // déjà demandé par _requestPermission()
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      // Tap sur une notif locale (déclenchée quand l'app est au premier plan
      // et qu'on affiche via flutter_local_notifications) — on parse le
      // payload JSON que _wireForegroundListener a sérialisé.
      onDidReceiveNotificationResponse: (resp) {
        if (resp.payload == null) return;
        try {
          final data = jsonDecode(resp.payload!) as Map<String, dynamic>;
          _routeFromPayload(_lastRef, data);
        } catch (e) {
          debugPrint('[FCM] tap payload parse failed: $e');
        }
      },
    );

    // Création explicite du channel Android (Android 8+).
    // Sans ça, les notifs n'apparaissent pas en heads-up avec son/vibration.
    const channel = AndroidNotificationChannel(
      _orderChannelId,
      _orderChannelName,
      description: _orderChannelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _localNotif
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── 3. Foreground handler : affiche via local notif ───────────────────────
  // Quand l'app est au premier plan, FCM délivre le RemoteMessage mais
  // n'affiche PAS de bandeau système. C'est à nous de le faire.
  static void _wireForegroundListener() {
    FirebaseMessaging.onMessage.listen((msg) async {
      final title = msg.notification?.title ?? msg.data['title'] as String? ?? 'ifè FOOD';
      final body  = msg.notification?.body  ?? msg.data['body']  as String? ?? '';
      debugPrint('[FCM] foreground msg: $title — data=${msg.data}');

      await _localNotif.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647), // id unique
        title, body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _orderChannelId, _orderChannelName,
            channelDescription: _orderChannelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            // icon: '@mipmap/ic_launcher', // default OK
          ),
          iOS: const DarwinNotificationDetails(presentSound: true),
        ),
        // Payload sérialisé pour le tap handler (qui ne peut pas accéder
        // directement au RemoteMessage).
        payload: jsonEncode(msg.data),
      );
    });
  }

  // ── 4. Token refresh ──────────────────────────────────────────────────────
  static void _wireTokenRefreshListener(Ref ref) {
    _lastRef = ref;
    _messaging.onTokenRefresh.listen((token) async {
      debugPrint('[FCM] token refreshed');
      // Le notifier auth gère le PATCH /users/me/fcm-token.
      await ref.read(authProvider.notifier).registerFcmToken(token);
    });
  }

  static Future<void> _registerCurrentToken(Ref ref) async {
    _lastRef = ref;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    debugPrint('[FCM] current token: ${token.substring(0, 12)}…');
    await ref.read(authProvider.notifier).registerFcmToken(token);
  }

  // ── 5. Tap handlers (background + terminated state) ───────────────────────
  static void _wireTapListeners(Ref ref) {
    _lastRef = ref;

    // App en arrière-plan, l'utilisateur tap sur la notif système.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      _routeFromPayload(ref, msg.data);
    });

    // App tuée, lancée par le tap sur une notif. Récupère le message initial.
    _messaging.getInitialMessage().then((msg) {
      if (msg == null) return;
      // Léger délai : le router GoRouter peut ne pas être prêt au tout 1er frame.
      Future.delayed(const Duration(milliseconds: 500), () {
        _routeFromPayload(ref, msg.data);
      });
    });
  }

  /// Référence Ref capturée pour le callback de tap des notifs LOCALES
  /// (qui n'expose pas de paramètre Ref). Mis à jour à chaque init/listener.
  static Ref? _lastRef;

  /// Route vers l'écran approprié selon le rôle + le payload data FCM.
  /// Payload attendu : `{ orderId: '...', status: 'PAID'|'ACCEPTED'|... }`.
  static void _routeFromPayload(Ref? ref, Map<String, dynamic> data) {
    if (ref == null) return;
    final orderId = data['orderId']?.toString();
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;
    final router = ref.read(routerProvider);

    // Pas d'orderId → tap sur une notif système non-commande (rare) → home.
    if (orderId == null || orderId.isEmpty) {
      router.go(_homeForRole(auth.role));
      return;
    }

    switch (auth.role) {
      case UserRole.professional:
        router.go('/pro/order/$orderId');
        break;
      case UserRole.client:
        router.go('/order/$orderId');
        break;
      case UserRole.driver:
        if (data['type'] == 'NEW_MISSION') {
          // Mission proposée : afficher le dialog accept/decline.
          // On va d'abord sur le dashboard (socket backdrop), puis on fetche
          // la commande pour construire la Mission et ouvrir le dialog.
          router.go('/driver/dashboard');
          _fetchAndShowMission(ref, orderId);
        } else {
          // Mission déjà acceptée : aller sur l'écran de suivi.
          router.go('/driver/active-mission');
        }
        break;
      case UserRole.admin:
      case null:
        router.go('/onboarding');
        break;
    }
  }

  /// Fetche la commande depuis le backend et affiche le IncomingMissionDialog.
  /// Appelé quand le driver tape une notif NEW_MISSION depuis l'arrière-plan.
  static Future<void> _fetchAndShowMission(Ref ref, String orderId) async {
    // Léger délai pour laisser le router terminer la navigation vers /driver/dashboard.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    try {
      final res = await ApiClient.instance.get('/orders/$orderId');
      final mission = Mission.fromOrderJson(res['data'] as Map<String, dynamic>);
      ref.read(driverProvider.notifier).showIncomingMission(mission);
    } catch (e) {
      debugPrint('[FCM] _fetchAndShowMission failed: $e');
    }
  }

  static String _homeForRole(UserRole? role) {
    switch (role) {
      case UserRole.professional: return '/pro/dashboard';
      case UserRole.driver:       return '/driver/dashboard';
      case UserRole.client:       return '/home';
      default:                    return '/onboarding';
    }
  }
}

/// Provider one-shot qui boot FCM dès qu'on le watch pour la 1ère fois.
/// À watcher depuis IfeFoodApp.build() pour garantir un seul appel.
/// La valeur retournée n'est pas utilisée — on s'en sert pour ses side effects.
final fcmBootstrapProvider = Provider<void>((ref) {
  // Pas d'await ici : init() est async mais on n'a pas besoin du résultat —
  // les listeners auth + tap se câblent de façon synchrone à l'intérieur,
  // les opérations réseau (token register) se font en best-effort.
  FcmService.init(ref);
});

