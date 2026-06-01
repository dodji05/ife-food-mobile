// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Options Firebase explicites
//
// Généré manuellement à partir de android/app/google-services.json (projet
// ife-food). Permet d'initialiser Firebase via :
//   Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
// sans dépendre du traitement natif de google-services.json par le plugin
// Gradle — qui échouait ([core/no-app]).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase web non configuré pour ifè FOOD.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        // iOS non configuré (pas de GoogleService-Info.plist) — on retombe
        // sur les options Android pour ne pas crasher ; à compléter si build iOS.
        return android;
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyDNIVDeZ74lHrTW3E-b-yxIKwT0DjXS9z0',
    appId:             '1:358690714175:android:9fd2468869cc3057e2fe8a',
    messagingSenderId: '358690714175',
    projectId:         'ife-food',
    storageBucket:     'ife-food.firebasestorage.app',
  );
}
