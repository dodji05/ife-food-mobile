# ifè FOOD — Application Unifiée : Guide d'intégration

## Architecture

```
lib/
├── main.dart                          ← Point d'entrée unique
├── core/
│   ├── api/api_client.dart            ← HTTP centralisé + auto-refresh JWT
│   ├── constants/app_constants.dart   ← Constantes + enum UserRole
│   ├── providers/
│   │   ├── auth_provider.dart         ← Auth centrale (OTP, PIN, rôle, logout)
│   │   ├── theme_provider.dart        ← Thème auto jour/nuit
│   │   └── location_provider.dart     ← GPS partagé
│   ├── router/app_router.dart         ← Routing basé sur rôle
│   ├── splash/splash_config.dart      ← Splash configurable
│   └── theme/app_theme.dart           ← 3 thèmes (light, dark, driver)
├── features/
│   ├── auth/                          ← Écrans partagés : onboarding, rôle, OTP, PIN
│   ├── client/                        ← Interface CLIENT (depuis ife-food-flutter)
│   ├── driver/                        ← Interface LIVREUR (depuis ife-food-driver)
│   └── professional/                  ← Interface PRO (depuis ife-food-pro)
└── shared/
    ├── models/app_user.dart           ← Modèle utilisateur unifié
    └── widgets/                       ← Composants réutilisables
```

---

## Étapes d'intégration des écrans existants

### Étape 1 — Copier les screens CLIENT
```
ife-food-flutter/lib/features/*/screens/*.dart
→ ife-food-unified/lib/features/client/screens/*/
```
Adaptations nécessaires :
- Remplacer les imports `../auth/providers/auth_provider.dart` par `../../../../core/providers/auth_provider.dart`
- Remplacer les imports de `app_theme.dart` de même

### Étape 2 — Copier les screens DRIVER
```
ife-food-driver/lib/features/*/screens/*.dart
→ ife-food-unified/lib/features/driver/screens/*/
```

### Étape 3 — Copier les screens PROFESSIONNEL
```
ife-food-pro/lib/features/*/screens/*.dart
→ ife-food-unified/lib/features/professional/screens/*/
```

### Étape 4 — Copier les providers
Copier les providers spécifiques à chaque module (ex : cartProvider, proProvider) dans :
- `lib/features/client/providers/`
- `lib/features/driver/providers/`
- `lib/features/professional/providers/`

### Étape 5 — Copier les modèles partagés
```
*/shared/models/*.dart → lib/shared/models/
```
(product.dart, order.dart, professional.dart, cart_item.dart, etc.)

---

## Logique de routage

```
App démarre
    │
    ▼
/splash (SplashScreen)
    │ splashDone = true
    ▼
Non connecté → /onboarding → /auth/role → /auth/phone → /auth/otp → /auth/pin → /auth/complete-profile
    │
Connecté
    ├── role = CLIENT       → /home          (ClientMainShell)
    ├── role = DRIVER       → /driver/dashboard (DriverShell)
    ├── role = PROFESSIONAL → /pro/dashboard  (ProShell)
    └── role = PENDING      → /auth/pending
```

---

## Splash Screen — Configuration

Modifier `lib/core/splash/splash_config.dart` :

```dart
static const SplashType type = SplashType.lottie;  // image | lottie | video | custom
static const String lottiePath = 'assets/animations/splash.json';
static const int minDurationMs = 2000;
```

Pour utiliser une vidéo :
```dart
static const SplashType type = SplashType.video;
static const String videoPath = 'assets/animations/splash.mp4';
```

---

## Thème — Comportement

| Heure | Mode automatique |
|-------|-----------------|
| 6h00 – 18h59 | Clair ☀️ |
| 19h00 – 5h59 | Sombre 🌙 |

Le thème sombre du LIVREUR (`AppTheme.driver`) est distinct du thème sombre générique.

---

## Démarrage local

```bash
cd ife-food-unified
flutter pub get
flutter run
```

---

## Publication

```bash
# Android (après avoir configuré key.properties)
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
# applicationId : bj.ifefood.app (unique — un seul Play Store listing)
```

---

## Ets SWK FAKEYE · Bénin · www.ifefood.bj · gildas31@gmail.com
