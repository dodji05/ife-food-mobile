// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Routeur unifié basé sur le rôle utilisateur
//
// Logique de routage :
//   1. splashDone=false   → /splash (animation de démarrage)
//   2. Non connecté       → /onboarding → /auth/...
//   3. Connecté CLIENT    → ShellRoute client  (/home, /orders, /profile)
//   4. Connecté DRIVER    → ShellRoute driver  (/driver/dashboard, ...)
//   5. Connecté PRO       → ShellRoute pro     (/pro/dashboard, ...)
//   6. Connecté PENDING   → /pending (attente validation)
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../constants/app_constants.dart';
import '../splash/splash_config.dart';

// Auth screens (partagés)
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/role_selection_screen.dart';
import '../../features/auth/screens/phone_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/pin_screen.dart';
import '../../features/auth/screens/complete_profile_screen.dart';
import '../../features/auth/screens/pending_screen.dart';

// CLIENT screens
import '../../features/client/screens/home/home_screen.dart';
import '../../features/client/screens/home/main_shell.dart';
import '../../features/client/screens/restaurant/restaurant_screen.dart';
import '../../features/client/screens/cart/cart_screen.dart';
import '../../features/client/screens/cart/checkout_screen.dart';
import '../../features/client/screens/order/order_history_screen.dart';
import '../../features/client/screens/order/order_detail_screen.dart';
import '../../features/client/screens/order/review_screen.dart';
import '../../features/client/screens/tracking/tracking_screen.dart';
import '../../features/client/screens/profile/profile_screen.dart';
import '../../features/client/screens/profile/addresses_screen.dart';
import '../../features/client/screens/search/search_screen.dart';
import '../../features/client/screens/notifications/notifications_screen.dart';
import '../../features/client/screens/legal/legal_screen.dart';

// DRIVER screens
import '../../features/driver/screens/dashboard/driver_shell.dart';
import '../../features/driver/screens/dashboard/driver_dashboard_screen.dart';
import '../../features/driver/screens/mission/mission_history_screen.dart';
import '../../features/driver/screens/earnings/driver_earnings_screen.dart';
import '../../features/driver/screens/profile/driver_profile_screen.dart';

// MISSIONS (emplacement canonique : features/driver)
import '../../features/driver/screens/mission/active_mission_screen.dart';

// PROFESSIONAL screens
import '../../features/professional/screens/dashboard/pro_shell.dart';
import '../../features/professional/screens/dashboard/pro_dashboard_screen.dart';
import '../../features/professional/screens/orders/pro_orders_screen.dart';
import '../../features/professional/screens/orders/pro_order_detail_screen.dart';
import '../../features/professional/screens/catalogue/catalogue_screen.dart';
import '../../features/professional/screens/catalogue/add_product_screen.dart';
import '../../features/professional/screens/schedule/schedule_screen.dart';
import '../../features/professional/screens/earnings/pro_earnings_screen.dart';
import '../../features/professional/screens/reviews/reviews_screen.dart';
import '../../features/professional/screens/profile/pro_profile_screen.dart';

// H2: keepAlive évite la recréation du GoRouter à chaque changement d'AuthState
final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();

  return GoRouter(
    initialLocation: '/splash',
    // H2: refreshListenable déclenche le redirect sans recréer le router
    refreshListenable: GoRouterRefreshStream(ref, authProvider),
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text(
        'Erreur de navigation : ${state.error?.toString() ?? 'inconnue'}',
        style: const TextStyle(fontFamily: 'Nunito'),
      )),
    ),
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final loc = state.matchedLocation;

      // ─── 1. SPLASH ─────────────────────────────────────────────────────
      // Bloque l'utilisateur sur /splash tant que _bootstrap n'a pas fini.
      if (!authState.splashDone) {
        return loc == '/splash' ? null : '/splash';
      }
      // Splash terminé → on calcule la destination en fonction de l'état
      // d'auth (la suite du redirect gère tous les cas).
      if (loc == '/splash') {
        if (!authState.isAuthenticated) return '/onboarding';
        if (authState.needsPinSetup)        return '/auth/pin';
        if (!authState.hasProfile)       return '/auth/complete-profile';
        return _homeForRole(authState.role);
      }

      // ─── 2. NON AUTHENTIFIÉ ────────────────────────────────────────────
      // Routes ouvertes au public (avant verifyOtp réussi).
      const publicRoutes = ['/onboarding', '/auth/role', '/auth/phone',
          '/auth/otp', '/legal/'];
      final isPublic = publicRoutes.any((r) => loc.startsWith(r));

      if (!authState.isAuthenticated) {
        return isPublic ? null : '/onboarding';
      }

      // ─── 3. AUTH FLOW EN COURS (source unique de vérité) ───────────────
      // Le redirect FORCE l'utilisateur sur le bon écran selon les flags
      // needsPinSetup et hasProfile. Les écrans OTP / PIN / complete-profile
      // n'ont PLUS de context.go() après leur action : ils mutent l'état
      // et c'est ICI que la nav est décidée.
      //
      // Avantages vs nav explicite côté widget :
      //   ✓ Pas de race "widget démonté avant context.go"
      //   ✓ Le hot-reload conserve l'état → le bon écran se ré-affiche
      //   ✓ Robuste aux deep links et back button
      //   ✓ Une seule fonction lit l'état → comportement prévisible
      //
      // a) On a un token mais le PIN n'est pas fait → bloquer sur /auth/pin
      if (authState.needsPinSetup) {
        return loc.startsWith('/auth/pin') ? null : '/auth/pin';
      }
      // b) PIN OK mais profil incomplet → bloquer sur /auth/complete-profile
      if (!authState.hasProfile) {
        return loc.startsWith('/auth/complete-profile')
            ? null
            : '/auth/complete-profile';
      }
      // c) Tout est complet : si l'utilisateur traîne encore sur un écran
      //    d'auth, le pousser vers son dashboard.
      const authRoutes = ['/onboarding', '/auth/role', '/auth/phone',
          '/auth/otp', '/auth/pin', '/auth/complete-profile'];
      if (authRoutes.any((r) => loc.startsWith(r))) {
        return _homeForRole(authState.role);
      }

      // ─── 4. ADMIN — non supporté sur mobile ────────────────────────────
      if (authState.role == UserRole.admin) {
        return '/onboarding';
      }

      // ─── 5. COMPTE PRO/DRIVER EN ATTENTE DE VALIDATION ─────────────────
      if (authState.isPending && loc != '/auth/pending') {
        if (authState.role == UserRole.professional ||
            authState.role == UserRole.driver) {
          return '/auth/pending';
        }
      }
      if (!authState.isPending && loc == '/auth/pending') {
        return _homeForRole(authState.role);
      }

      // ─── 6. VÉRIFICATION CROSS-RÔLE ─────────────────────────────────────
      if (authState.role == UserRole.client && loc.startsWith('/pro')) return '/home';
      if (authState.role == UserRole.client && loc.startsWith('/driver')) return '/home';
      if (authState.role == UserRole.driver && loc.startsWith('/home')) return '/driver/dashboard';
      if (authState.role == UserRole.driver && loc.startsWith('/pro')) return '/driver/dashboard';
      if (authState.role == UserRole.professional && loc.startsWith('/home')) return '/pro/dashboard';
      if (authState.role == UserRole.professional && loc.startsWith('/driver')) return '/pro/dashboard';

      return null;
    },

    routes: [
      // ── Splash ─────────────────────────────────────────────────────────────
      // splashDone est géré dans AuthNotifier._bootstrap() — le SplashScreen
      // n'a plus besoin d'onComplete pour déclencher la navigation.
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      // ── Auth partagé ────────────────────────────────────────────────────────
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/auth/role',  builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: '/auth/phone', builder: (_, state) {
        // extra direct = UserRole (passé par role_selection_screen)
        final role = (state.extra is UserRole) ? state.extra as UserRole : UserRole.client;
        return PhoneScreen(role: role);
      }),
      GoRoute(path: '/auth/otp', builder: (_, state) {
        final extras = _Extras.asMap(state.extra);
        final phone     = _Extras.read<String>(extras, 'phone');
        final sessionId = _Extras.read<String>(extras, 'sessionId');
        // Champs obligatoires manquants → écran d'erreur explicite (au lieu
        // d'un crash sur un cast null!.)
        if (phone == null || sessionId == null) {
          return _Extras.missingParams('/auth/otp', [
            if (phone == null)     'phone',
            if (sessionId == null) 'sessionId',
          ]);
        }
        return OtpScreen(
          phone:       phone,
          sessionId:   sessionId,
          countryCode: _Extras.read<String>(extras, 'countryCode', fallback: 'BJ')!,
          role:        _Extras.read<UserRole>(extras, 'role', fallback: UserRole.client)!,
          prefillOtp:  _Extras.read<String>(extras, 'prefillOtp'),
        );
      }),
      GoRoute(path: '/auth/pin', builder: (_, state) {
        // Les extras sont OPTIONNELS : PinScreen lit `mode`/`phone` depuis
        // l'AuthState (isNewUser / user.phone). Les extras servent uniquement
        // de rétro-compat si l'écran est ouvert par navigation manuelle.
        final extras = _Extras.asMap(state.extra);
        return PinScreen(
          mode:  _Extras.read<String>(extras, 'mode'),
          phone: _Extras.read<String>(extras, 'phone'),
        );
      }),
      GoRoute(path: '/auth/complete-profile', builder: (_, state) {
        final role = (state.extra is UserRole) ? state.extra as UserRole : UserRole.client;
        return CompleteProfileScreen(role: role);
      }),
      GoRoute(path: '/auth/pending', builder: (_, __) => const PendingScreen()),

      // ── Legal (partagé) ─────────────────────────────────────────────────────
      GoRoute(path: '/legal/:type', builder: (_, state) =>
          LegalScreen(type: state.pathParameters['type']!)),

      // ════════════════════════════════════════════════════════════════════════
      // CLIENT routes
      // ════════════════════════════════════════════════════════════════════════
      ShellRoute(
        builder: (_, __, child) => ClientMainShell(child: child),
        routes: [
          GoRoute(path: '/home',    builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/orders',  builder: (_, __) => const OrderHistoryScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ClientProfileScreen()),
        ],
      ),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/restaurant/:id', builder: (_, state) =>
          RestaurantScreen(restaurantId: state.pathParameters['id']!)),
      GoRoute(path: '/cart',     builder: (_, __) => const CartScreen()),
      GoRoute(path: '/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/order/:id', builder: (_, state) =>
          OrderDetailScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/order/:id/review', builder: (_, state) =>
          ReviewScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/tracking/:orderId', builder: (_, state) =>
          TrackingScreen(orderId: state.pathParameters['orderId']!)),
      GoRoute(path: '/addresses',     builder: (_, __) => const AddressesScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      // ════════════════════════════════════════════════════════════════════════
      // DRIVER routes (préfixe /driver)
      // ════════════════════════════════════════════════════════════════════════
      ShellRoute(
        builder: (_, __, child) => DriverShell(child: child),
        routes: [
          GoRoute(path: '/driver/dashboard', builder: (_, __) => const DriverDashboardScreen()),
          GoRoute(path: '/driver/missions',  builder: (_, __) => const MissionHistoryScreen()),
          GoRoute(path: '/driver/earnings',  builder: (_, __) => const DriverEarningsScreen()),
          GoRoute(path: '/driver/profile',   builder: (_, __) => const DriverProfileScreen()),
        ],
      ),
      GoRoute(path: '/driver/active-mission', builder: (_, __) => const ActiveMissionScreen()),
      // Navigation GPS externe (lat/lng/label passés en extra)
      GoRoute(path: '/navigate', builder: (_, state) {
        final extras = _Extras.asMap(state.extra);
        final lat   = _Extras.read<double>(extras, 'lat',   fallback: 0.0)!;
        final lng   = _Extras.read<double>(extras, 'lng',   fallback: 0.0)!;
        final label = _Extras.read<String>(extras, 'label', fallback: 'Destination')!;
        // Lance la navigation externe (Google Maps / Waze)
        // Pour l'instant : écran de fallback avec les coordonnées
        return Scaffold(
          appBar: AppBar(title: Text(label)),
          body: Center(child: Text(
            'Navigation vers $label\n($lat, $lng)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 16),
          )),
        );
      }),

      // ════════════════════════════════════════════════════════════════════════
      // PROFESSIONAL routes (préfixe /pro)
      // ════════════════════════════════════════════════════════════════════════
      ShellRoute(
        builder: (_, __, child) => ProShell(child: child),
        routes: [
          GoRoute(path: '/pro/dashboard', builder: (_, __) => const ProDashboardScreen()),
          GoRoute(path: '/pro/orders',    builder: (_, __) => const ProOrdersScreen()),
          GoRoute(path: '/pro/catalogue', builder: (_, __) => const CatalogueScreen()),
          GoRoute(path: '/pro/earnings',  builder: (_, __) => const ProEarningsScreen()),
          GoRoute(path: '/pro/profile',   builder: (_, __) => const ProProfileScreen()),
        ],
      ),
      GoRoute(path: '/pro/order/:id', builder: (_, state) =>
          ProOrderDetailScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/pro/add-product', builder: (_, state) =>
          AddProductScreen(product: _Extras.asMap(state.extra))),
      GoRoute(path: '/pro/schedule', builder: (_, __) => const ScheduleScreen()),
      GoRoute(path: '/pro/reviews',  builder: (_, __) => const ReviewsScreen()),
    ],
  );
});

// Destination home selon le rôle
String _homeForRole(UserRole? role) => switch (role) {
  UserRole.driver       => '/driver/dashboard',
  UserRole.professional => '/pro/dashboard',
  _                     => '/home',
};

// ─────────────────────────────────────────────────────────────────────────────
// _Extras — helpers pour extraire les paramètres passés via context.go(extra:)
//
// Pourquoi : `state.extra` est typé `Object?`. Sans helper, chaque builder
// duplique les casts (et oublie souvent les null guards). Ces fonctions
// centralisent l'extraction et fournissent un Scaffold d'erreur clair quand
// un paramètre obligatoire manque (au lieu d'un crash silencieux).
// ─────────────────────────────────────────────────────────────────────────────
class _Extras {
  /// Lit `extra` comme une Map. Renvoie null si absent ou mal typé.
  static Map<String, dynamic>? asMap(Object? extra) =>
      extra is Map<String, dynamic> ? extra : null;

  /// Lit une valeur typée depuis la map des extras. Renvoie [fallback] si
  /// absent ou du mauvais type.
  static T? read<T>(Map<String, dynamic>? extras, String key, {T? fallback}) {
    final v = extras?[key];
    return v is T ? v : fallback;
  }

  /// Écran d'erreur affiché quand un paramètre obligatoire manque.
  /// On dit clairement ce qui manque pour faciliter le debug.
  static Widget missingParams(String routeName, List<String> missing) =>
      Scaffold(
        appBar: AppBar(title: Text('Erreur — $routeName')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text(
                  'Paramètres de navigation manquants',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Route : $routeName\nManquant : ${missing.join(", ")}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Nunito', fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// GoRouterRefreshStream — pont Riverpod ↔ GoRouter
//
// Rôle : GoRouter ne sait pas écouter un provider Riverpod nativement. On lui
// donne un ChangeNotifier qu'il sait écouter (via `refreshListenable`), et on
// le nourrit en relayant les changements de l'AuthNotifier.
//
// Optimisation clé : on ne notifie que si les champs ROUTING-RELEVANTS ont
// changé (isAuthenticated, splashDone, role, isPending). Les toggles
// `isLoading` pendant une requête API ne déclenchent PAS de re-évaluation
// du redirect — sans ça, chaque appel `sendOtp/verifyOtp/setPin` ferait
// tourner le redirect 2 fois inutilement et augmenterait la probabilité de
// races (cf. commentaire OTP dans la fonction redirect).
// ─────────────────────────────────────────────────────────────────────────────
class GoRouterRefreshStream extends ChangeNotifier {
  late final ProviderSubscription _sub;

  GoRouterRefreshStream(
      Ref ref, StateNotifierProvider<AuthNotifier, AuthState> provider) {
    _sub = ref.listen<AuthState>(provider, (prev, next) {
      if (_routingFieldsChanged(prev, next)) notifyListeners();
    }, fireImmediately: false);
  }

  /// True ssi un champ qui INFLUE sur le redirect a changé.
  /// Liste à garder synchrone avec les conditions de la fonction redirect.
  static bool _routingFieldsChanged(AuthState? prev, AuthState next) {
    if (prev == null) return true;
    return prev.isAuthenticated != next.isAuthenticated
        || prev.splashDone      != next.splashDone
        || prev.role            != next.role
        || prev.isPending       != next.isPending
        || prev.needsPinSetup      != next.needsPinSetup
        || prev.hasProfile      != next.hasProfile;
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
