// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Point d'entrée de l'application unifiée
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/api/api_client.dart';
import 'core/notifications/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/constants/app_constants.dart';

/// Handler FCM en arrière-plan / app tuée.
/// DOIT être une fonction top-level annotée @pragma('vm:entry-point') sinon
/// Flutter ne peut pas la rejouer dans l'isolate background.
/// Le payload backend contient un bloc `notification` -> Android/iOS affichent
/// la notif système automatiquement, on n'a rien à faire ici.
/// (Hook réservé pour future logique : badge, persistance offline, etc.)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientation portrait uniquement
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Barre système transparente
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  // Hive (cache local)
  await Hive.initFlutter();

  // Firebase (push notifications)
  try {
    await Firebase.initializeApp();
    // Background handler enregistré APRÈS init et AVANT runApp — sinon
    // les messages reçus app fermée ne sont pas dispatchés à l'isolate.
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
  } catch (_) {
    // Firebase optionnel en dev sans google-services.json
  }

  runApp(const ProviderScope(child: IfeFoodApp()));
}

// ─────────────────────────────────────────────────────────────────────────────
// Application racine
// ─────────────────────────────────────────────────────────────────────────────
class IfeFoodApp extends ConsumerWidget {
  const IfeFoodApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router     = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);
    final authState  = ref.watch(authProvider);

    // Bootstrap FCM une seule fois — Provider one-shot qui câble permission,
    // token register, listener auth, handlers foreground/tap.
    // Doit être watché APRÈS routerProvider (FcmService a besoin de naviguer
    // sur tap → lit ref.read(routerProvider)).
    ref.watch(fcmBootstrapProvider);

    // Choisit le bon thème sombre selon le profil connecté
    final darkTheme = authState.role == UserRole.driver
        ? AppTheme.driver   // Dark électrique pour les livreurs
        : AppTheme.dark;    // Dark navy pour les autres

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Messenger global — permet d'afficher des snackbars depuis n'importe
      // quelle couche (ex: AuthEvents session expirée) sans BuildContext.
      scaffoldMessengerKey: AppMessenger.scaffoldMessengerKey,

      // Thèmes
      theme:     AppTheme.light,
      darkTheme: darkTheme,
      themeMode: themeState.themeMode,

      // Navigation
      routerConfig: router,

      // Localisation
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'), Locale('en'), Locale('es'),
        Locale('de'), Locale('ru'), Locale('ar'), Locale('zh'),
      ],
    );
  }
}
