// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Point d'entrée de l'application unifiée
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/constants/app_constants.dart';

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

    // Choisit le bon thème sombre selon le profil connecté
    final darkTheme = authState.role == UserRole.driver
        ? AppTheme.driver   // Dark électrique pour les livreurs
        : AppTheme.dark;    // Dark navy pour les autres

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

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
