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
import 'route_params.dart';

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
import '../../features/client/screens/order/tip_screen.dart';
import '../../features/client/screens/tracking/tracking_screen.dart';
import '../../features/client/screens/profile/profile_screen.dart';
import '../../features/client/screens/profile/edit_profile_screen.dart';
import '../../features/client/screens/profile/addresses_screen.dart';
import '../../features/client/screens/profile/address_form_screen.dart';
import '../../features/client/screens/search/search_screen.dart';
// NotificationsScreen (ancien) remplacé par ClientNotificationsScreen
// qui réutilise le widget shared NotificationsListWidget + le provider core.
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
import '../../features/professional/screens/catalogue/manage_categories_screen.dart';
import '../../features/professional/screens/notifications/pro_notifications_screen.dart';
import '../../features/admin/screens/admin_pending_screen.dart';
import '../../features/client/screens/notifications/client_notifications_screen.dart';
import '../../features/driver/screens/notifications/driver_notifications_screen.dart';
import '../../features/driver/screens/map/navigation_screen.dart';
import '../../features/driver/screens/auth/driver_vehicle_screen.dart';
import '../../features/professional/screens/schedule/schedule_screen.dart';
import '../../features/professional/screens/earnings/pro_earnings_screen.dart';
import '../../features/professional/screens/reviews/reviews_screen.dart';
import '../../features/professional/screens/profile/pro_profile_screen.dart';
import '../../features/professional/screens/profile/edit_business_info_screen.dart';
import '../../features/professional/screens/drivers/favorite_drivers_screen.dart';
import '../../features/professional/screens/promo/pro_promo_screen.dart';
import '../../features/professional/screens/referral/pro_referral_screen.dart';
import '../../features/professional/screens/chat/pro_chat_screen.dart';
import '../../features/professional/screens/profile/pro_documents_screen.dart';
import '../../shared/screens/chat_screen.dart';
import '../../features/client/screens/messages/inbox_screen.dart';

// H2: keepAlive évite la recréation du GoRouter à chaque changement d'AuthState
final routerProvider = Provider<GoRouter>((ref) {
  ref.keepAlive();

  return GoRouter(
    initialLocation: '/splash',
    // H2: refreshListenable déclenche le redirect sans recréer le router
    refreshListenable: GoRouterRefreshStream(ref, authProvider),
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFFFF3B30),
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 64),
          const SizedBox(height: 16),
          const Text('ERREUR DE ROUTAGE', textAlign: TextAlign.center,
            style: TextStyle(fontFamily: 'Nunito', fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 12),
          Text(state.error?.toString() ?? 'Route inconnue', textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Nunito', fontSize: 14, color: Colors.white, height: 1.4)),
        ]),
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
      //
      //    EXCEPTION : "Modifier mon PIN" depuis le profil pousse vers
      //    /auth/pin avec PinRouteParams(mode: 'set'). On laisse passer
      //    pour permettre le changement de PIN sans créer une route dédiée.
      const authRoutes = ['/onboarding', '/auth/role', '/auth/phone',
          '/auth/otp', '/auth/pin', '/auth/complete-profile'];
      if (authRoutes.any((r) => loc.startsWith(r))) {
        final extra = state.extra;
        final isChangePin = loc.startsWith('/auth/pin')
            && extra is PinRouteParams
            && extra.mode == 'set';
        if (!isChangePin) return _homeForRole(authState.role);
      }

      // ─── 4. ADMIN — accès limité aux écrans /admin/* ───────────────────
      // L'admin peut maintenant valider/refuser pros et drivers depuis
      // /admin/pending. Tout autre chemin redirige vers cette home admin.
      if (authState.role == UserRole.admin) {
        if (!loc.startsWith('/admin')) return '/admin/pending';
        return null; // déjà sur une route admin, OK
      }

      // ─── 5. COMPTE PRO/DRIVER EN ATTENTE DE VALIDATION ─────────────────
      // Exception : /auth/driver-vehicle est une étape d'onboarding driver
      // qui DOIT s'exécuter avant le redirect /auth/pending (sinon le user
      // ne peut jamais créer son Driver profile). On laisse passer.
      if (authState.isPending
          && loc != '/auth/pending'
          && loc != '/auth/driver-vehicle') {
        if (authState.role == UserRole.professional ||
            authState.role == UserRole.driver) {
          return '/auth/pending';
        }
      }
      if (!authState.isPending && loc == '/auth/pending') {
        return _homeForRole(authState.role);
      }
      // Si l'utilisateur n'est pas driver mais arrive sur /auth/driver-vehicle
      // (deep link incorrect), on le redirige vers sa home.
      if (loc == '/auth/driver-vehicle' && authState.role != UserRole.driver) {
        return _homeForRole(authState.role);
      }

      // ─── 6. VÉRIFICATION CROSS-RÔLE ─────────────────────────────────────
      // Utiliser '/pro/' (avec slash) et non '/pro' — sinon '/profile'
      // (route client) serait bloqué car il commence aussi par '/pro'.
      if (authState.role == UserRole.client && loc.startsWith('/pro/')) return '/home';
      if (authState.role == UserRole.client && loc.startsWith('/driver/')) return '/home';
      if (authState.role == UserRole.driver && loc.startsWith('/home')) return '/driver/dashboard';
      if (authState.role == UserRole.driver && loc.startsWith('/pro/')) return '/driver/dashboard';
      if (authState.role == UserRole.professional && loc.startsWith('/home')) return '/pro/dashboard';
      if (authState.role == UserRole.professional && loc.startsWith('/driver/')) return '/pro/dashboard';

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
        // Type strict : OtpRouteParams. Si l'extra est manquant ou du mauvais
        // type (deep link, hot reload), on affiche un écran d'erreur clair
        // plutôt qu'un crash.
        final p = state.extra;
        if (p is! OtpRouteParams) {
          return _Extras.missingParams('/auth/otp', const ['OtpRouteParams']);
        }
        return OtpScreen(
          phone:       p.phone,
          sessionId:   p.sessionId,
          countryCode: p.countryCode,
          role:        p.role,
          prefillOtp:  p.prefillOtp,
        );
      }),
      GoRoute(path: '/auth/pin', builder: (_, state) {
        // Extras OPTIONNELS : PinScreen lit `mode`/`phone` depuis l'AuthState
        // (isNewUser / user.phone). PinRouteParams sert au "Modifier mon PIN"
        // depuis le profil ou à un deep link.
        final p = state.extra is PinRouteParams
            ? state.extra as PinRouteParams
            : const PinRouteParams();
        return PinScreen(mode: p.mode, phone: p.phone);
      }),
      GoRoute(path: '/auth/complete-profile', builder: (_, state) {
        final role = (state.extra is UserRole) ? state.extra as UserRole : UserRole.client;
        return CompleteProfileScreen(role: role);
      }),
      GoRoute(path: '/auth/pending', builder: (_, __) => const PendingScreen()),
      // Étape véhicule driver (entre complete-profile et pending).
      // Sprint 4 : appelle POST /drivers/register puis go /auth/pending.
      GoRoute(path: '/auth/driver-vehicle', builder: (_, __) => const DriverVehicleScreen()),

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
      GoRoute(path: '/order/:id/tip', builder: (_, state) =>
          TipScreen(orderId: state.pathParameters['id']!)),
      GoRoute(path: '/tracking/:orderId', builder: (_, state) =>
          TrackingScreen(orderId: state.pathParameters['orderId']!)),
      GoRoute(path: '/addresses',         builder: (_, __) => const AddressesScreen()),
      // Form add/edit. /addresses/new = create (initial=null), /addresses/edit/:id
      // = edit (extra=Map<String,dynamic> de l'adresse à pré-remplir).
      GoRoute(path: '/addresses/new',     builder: (_, __) => const AddressFormScreen()),
      GoRoute(
        path: '/addresses/edit/:id',
        builder: (_, state) => AddressFormScreen(
          addressId: state.pathParameters['id'],
          initial:   _Extras.asMap(state.extra),
        ),
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const ClientNotificationsScreen()),
      GoRoute(path: '/profile/edit',  builder: (_, __) => const ClientEditProfileScreen()),
      GoRoute(path: '/messages/inbox', builder: (_, __) => const InboxScreen()),
      GoRoute(path: '/chat/:orderId', builder: (_, state) =>
          ChatScreen(orderId: state.pathParameters['orderId']!, title: 'Messagerie commande')),

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
      GoRoute(path: '/driver/notifications', builder: (_, __) => const DriverNotificationsScreen()),
      GoRoute(path: '/driver/chat/:orderId', builder: (_, state) =>
          ChatScreen(orderId: state.pathParameters['orderId']!, title: 'Messagerie client')),
      // Navigation GPS externe — NavigateRouteParams obligatoire.
      // Affiche une Google Map plein écran avec marker destination + CTA
      // pour ouvrir Google Maps en mode navigation native (deep link).
      GoRoute(path: '/navigate', builder: (_, state) {
        final p = state.extra;
        if (p is! NavigateRouteParams) {
          return _Extras.missingParams('/navigate', const ['NavigateRouteParams']);
        }
        return DriverNavigationScreen(lat: p.lat, lng: p.lng, label: p.label);
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
      GoRoute(path: '/pro/edit-info',  builder: (_, __) => const EditBusinessInfoScreen()),
      GoRoute(path: '/pro/categories',    builder: (_, __) => const ManageCategoriesScreen()),
      GoRoute(path: '/pro/notifications',     builder: (_, __) => const ProNotificationsScreen()),
      GoRoute(path: '/pro/favorite-drivers', builder: (_, __) => const FavoriteDriversScreen()),
      GoRoute(path: '/pro/promo',            builder: (_, __) => const ProPromoScreen()),
      GoRoute(path: '/pro/referral',         builder: (_, __) => const ProReferralScreen()),
      GoRoute(path: '/pro/chat/:orderId',    builder: (_, state) =>
          ProChatScreen(orderId: state.pathParameters['orderId']!)),
      GoRoute(path: '/pro/documents',        builder: (_, __) => const ProDocumentsScreen()),

      // ════════════════════════════════════════════════════════════════════════
      // 🛡️ ADMIN — un seul écran pour l'instant (validation pros/drivers).
      //    Gated par le redirect (cf. ligne 152 : non-/admin/* -> /admin/pending).
      // ════════════════════════════════════════════════════════════════════════
      GoRoute(path: '/admin/pending', builder: (_, __) => const AdminPendingScreen()),
    ],
  );
});

// Destination home selon le rôle
String _homeForRole(UserRole? role) => switch (role) {
  UserRole.admin        => '/admin/pending',
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
// Optimisation clé : on ne notifie que si un champ ROUTING-RELEVANT change
// (cf. _routingFieldsChanged). Les toggles `isLoading` pendant une requête
// API ne déclenchent PAS de re-évaluation du redirect — ça évite des
// rebuilds inutiles et garantit que le redirect ne s'exécute que quand
// la décision de routage peut réellement changer.
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
        || prev.needsPinSetup   != next.needsPinSetup
        || prev.hasProfile      != next.hasProfile
        // user.status peut changer via refreshProfile() depuis /auth/pending
        // (admin valide un compte PENDING → ACTIVE). Comparaison directe car
        // isPending est un getter dérivé qui ne se mémorise pas.
        ;
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
