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

      // 1. Splash pas encore terminé
      if (!authState.splashDone) {
        return loc == '/splash' ? null : '/splash';
      }

      // 2. Splash terminé → quitter /splash obligatoirement
      if (loc == '/splash') {
        return authState.isAuthenticated
            ? _homeForRole(authState.role)
            : '/onboarding';
      }

      // 3. Non authentifié
      // Toutes les routes accessibles sans token
      const publicRoutes = ['/onboarding', '/auth/role',
          '/auth/phone', '/auth/otp', '/auth/pin', '/auth/complete-profile'];
      final isPublic = publicRoutes.any((r) => loc.startsWith(r));

      if (!authState.isAuthenticated) {
        return isPublic ? null : '/onboarding';
      }

      // 3b. Authentifié — rediriger UNIQUEMENT depuis les routes purement
      //     pré-connexion. /auth/otp est EXCLU : l'utilisateur reçoit
      //     `isAuthenticated:true` PENDANT qu'il est sur cet écran (réponse
      //     verifyOtp), et le redirect le sortirait avant que otp_screen ait
      //     le temps de faire context.go('/auth/pin'). La navigation après
      //     OTP est gérée explicitement par otp_screen.dart.
      const preAuthRoutes = ['/onboarding', '/auth/role', '/auth/phone'];
      if (preAuthRoutes.any((r) => loc.startsWith(r))) {
        return _homeForRole(authState.role);
      }

      // 4. Compte admin non supporté sur mobile
      if (authState.role == UserRole.admin) {
        return '/onboarding';
      }

      // 5. Compte en attente de validation (pro / driver)
      if (authState.isPending && loc != '/auth/pending') {
        if (authState.role == UserRole.professional ||
            authState.role == UserRole.driver) {
          return '/auth/pending';
        }
      }
      // 5b. Compte activé sur /auth/pending → rediriger vers le bon tableau de bord
      if (!authState.isPending && loc == '/auth/pending') {
        return _homeForRole(authState.role);
      }

      // 6. Vérification cross-role
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
        final role = state.extra as UserRole? ?? UserRole.client;
        return PhoneScreen(role: role);
      }),
      GoRoute(path: '/auth/otp', builder: (_, state) {
        // H5: cast sécurisé — évite crash sur deep link sans extra
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null) {
          return const Scaffold(body: Center(
            child: Text('Paramètres de navigation manquants',
                style: TextStyle(fontFamily: 'Nunito'))));
        }
        return OtpScreen(
            phone: extra['phone'] as String,
            sessionId: extra['sessionId'] as String,
            countryCode: extra['countryCode'] as String? ?? 'BJ',
            role: extra['role'] as UserRole? ?? UserRole.client,
            prefillOtp: extra['prefillOtp'] as String?);
      }),
      GoRoute(path: '/auth/pin', builder: (_, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return PinScreen(mode: extra['mode'] ?? 'set', phone: extra['phone']);
      }),
      GoRoute(path: '/auth/complete-profile', builder: (_, state) {
        final role = state.extra as UserRole? ?? UserRole.client;
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
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final lat   = extra['lat']   as double? ?? 0.0;
        final lng   = extra['lng']   as double? ?? 0.0;
        final label = extra['label'] as String? ?? 'Destination';
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
          AddProductScreen(product: state.extra as Map<String, dynamic>?)),
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

// ── Helper : rend GoRouter réactif aux changements d'AuthState ────────────────
class GoRouterRefreshStream extends ChangeNotifier {
  late final ProviderSubscription _sub;

  GoRouterRefreshStream(Ref ref, StateNotifierProvider<AuthNotifier, AuthState> provider) {
    _sub = ref.listen(provider, (_, __) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
