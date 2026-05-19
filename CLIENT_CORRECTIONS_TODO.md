# ifè FOOD — TODO corrections côté CLIENT

> Audit réalisé le 2026-05-19. Tous les paths sont relatifs à `lib/`.

## Légende
- 🔴 **Bloquant** : empêche d'utiliser une fonctionnalité métier
- 🟡 **Important** : dégrade l'UX, contourne mais frustrant
- 🟢 **Améliorations** : nice-to-have, qualité

---

## 🔴 TIER 1 — Bugs bloquants

### 1. Home écran blanc — crash silencieux possible
**Fichier** : `features/client/screens/home/home_screen.dart:80`

```dart
// ❌ AVANT (crash si displayName = "")
Text(user?.displayName.substring(0, 1).toUpperCase() ?? '?', ...)
```
`.substring(0,1)` throw `RangeError` AVANT que le `?? '?'` puisse réagir.

**✅ Fix appliqué** dans cette session : guard `.isNotEmpty` ajouté.

### 2. Home — aucun état d'erreur si backend renvoie une liste vide
**Fichier** : `features/client/screens/home/home_screen.dart:131-178`

Quand `/geo/nearby` renvoie `[]`, on affiche juste "😔 Aucun établissement". Mais l'utilisateur ne sait pas si c'est un vrai vide ou un bug réseau silencieux.

**✅ Fix appliqué** : ajout d'un bouton "Réessayer" + diagnostic visible (lat/lng utilisés).

### 3. Backend `/geo/nearby` exige auth ET utilise lat/lng hardcodés
**Fichiers** :
- `features/client/screens/home/home_screen.dart:13-19`
- `core/constants/app_constants.dart:34-35`

`AppConstants.defaultLat/Lng = Cotonou`. Si le user est ailleurs OU si aucun pro n'est validé dans 15 km → écran vide en permanence.

**Action requise** :
1. Câbler `location_provider.dart` pour obtenir la vraie position GPS
2. Fallback sur lat/lng Cotonou seulement si permission refusée
3. Demander la permission GPS au lancement (déjà géré côté natif mais pas explicitement déclenchée)

### 4. Tracking livreur — données hardcodées
**Fichier** : `features/client/screens/tracking/tracking_screen.dart:19-23, 160-163`

```dart
LatLng _deliveryPosition = const LatLng(6.3700, 2.4250); // ❌ hardcodé
int _etaMinutes = 12;                                     // ❌ hardcodé
String _status = 'IN_DELIVERY';                           // ❌ hardcodé
```

Les `_StatusStep` sont tous `done: true` quel que soit le statut réel de l'order.

**Action** :
- Lire l'adresse de livraison réelle depuis `orderDetailProvider`
- Calculer l'ETA depuis la position du driver
- Mapper les statuts order (`PENDING`, `ACCEPTED`, `PREPARING`, `READY`, `IN_DELIVERY`, `DELIVERED`) sur les steps

### 5. Paiement sans confirmation — bouton "Payer" mène à `/order/:id` sans WebView
**Fichier** : `features/client/screens/cart/checkout_screen.dart:73-77`

```dart
await ApiClient.instance.post('/payments/$orderId/initiate/$_selectedPayment');
ref.read(cartProvider.notifier).clearCart();
if (mounted) context.go('/order/$orderId');  // ❌ pas de WebView paiement
```

L'utilisateur n'a aucune confirmation visuelle que le paiement Mobile Money / carte a réussi. La réponse de `/payments/.../initiate/...` contient typiquement une URL ou un payment intent qu'il faut afficher dans une WebView (KKiaPay/FedaPay/PayPal/Stripe).

**Action** :
- Ouvrir une `WebView` (`webview_flutter`) avec l'URL retournée par le backend
- Écouter le callback de succès/échec (deep link ou polling sur `/orders/:id`)
- Afficher écran "✅ Paiement réussi" ou "❌ Échec → réessayer"

### 6. Pas de CTA "Laisser un avis" sur commande livrée
**Fichier** : `features/client/screens/order/order_detail_screen.dart`

L'écran de détail d'une commande DELIVERED n'affiche **aucun bouton** pour aller sur `/order/:id/review`. La route existe mais est inaccessible.

**Action** : ajouter un bouton `ElevatedButton` "Noter cette commande" dans le détail si `o.isDelivered && !o.hasReview`.

### 7. Recherche produit cassée — tap ne navigue pas
**Fichier** : `features/client/screens/search/search_screen.dart:88`

```dart
onTap: () {}, // ❌ vide
```

**Action** : pousser vers le restaurant parent du produit : `context.push('/restaurant/${product.professionalId}')`.

---

## 🟡 TIER 2 — Bugs UX importants

### 8. Pas d'écran d'édition profil (nom/email/téléphone)
**Fichier** : `features/client/screens/profile/profile_screen.dart`

Le code admet la limite en commentaire ([profile_screen.dart:46-48]). L'utilisateur ne peut modifier que l'avatar.

**✅ Fix appliqué** dans cette session : création de `ClientEditProfileScreen` + route `/profile/edit` + menu.

### 9. Panier non persistant (perte au logout/restart)
**Fichier** : `features/client/providers/cart_provider.dart`

Le `StateNotifier` est uniquement en mémoire. Hive est déjà initialisé dans `main.dart:43` mais pas utilisé pour le panier.

**Action** :
- Ouvrir une box Hive `cart` au démarrage
- Sérialiser `CartState` via `toJson`/`fromJson`
- Restorer au démarrage du provider, sauver à chaque mutation

### 10. Frais de livraison non calculés — affichés "• • •"
**Fichier** : `features/client/screens/cart/cart_screen.dart:87`

```dart
_SummaryRow(label: 'Livraison', value: '• • •'),  // ❌
```

**Action** : appeler un endpoint `/orders/estimate` ou `/delivery-fee` avec la distance pro → adresse, ou intégrer la valeur depuis `Professional.deliveryFee`.

### 11. Adresse — pas de map picker pour lat/lng
**Fichier** : `features/client/screens/profile/address_form_screen.dart`

Le user saisit l'adresse en texte libre mais lat/lng restent null. Au checkout, fallback sur `defaultLat/Lng` → l'algo de matching driver peut envoyer le livreur n'importe où.

**Action** : ajouter un widget Google Maps avec marker draggable + bouton "Utiliser ma position actuelle".

### 12. Messagerie livreur — bouton stub "bientôt disponible"
**Fichier** : `features/client/screens/tracking/tracking_screen.dart:92-97`

Le backend a un module `messages/*` mais pas d'UI client.

**Action** :
- Créer `/chat/:orderId` (WebSocket sur namespace `/messages`)
- Liste des messages + input texte + envoi via `POST /messages/orders/:orderId`

### 13. Page restaurant — `_tabController` créé mais inutilisé
**Fichier** : `features/client/screens/restaurant/restaurant_screen.dart:26-32`

```dart
late TabController _tabController;
@override void initState() { _tabController = TabController(length: 2, vsync: this); }
```

Aucun `TabBar` ne l'utilise → fuite mémoire mineure et code mort.

**Action** : soit retirer, soit implémenter les tabs (ex: "Produits" / "Avis").

### 14. Page restaurant — section "Avis" absente
**Fichier** : `features/client/screens/restaurant/restaurant_screen.dart`

Le rating moyen et le nombre d'avis sont affichés mais on ne peut pas lire les commentaires.

**Action** : section "Avis" (5 derniers) avec `GET /reviews/professional/:id`.

### 15. Page restaurant — pas de gestion produits indisponibles
**Fichier** : `features/client/screens/restaurant/restaurant_screen.dart:171-283`

Si `product.isAvailable == false`, on peut quand même cliquer "+" et l'ajouter au panier. Backend rejettera au moment du checkout → UX confuse.

**Action** : griser le bouton + badge "Indisponible" si `!product.isAvailable`.

---

## 🟢 TIER 3 — Améliorations

### 16. Géolocalisation au lancement
- Demander la permission au cold start si l'utilisateur est CLIENT
- Stocker la dernière position connue dans Hive
- Bouton "📍 Cotonou, Bénin" sur le Home doit ouvrir un sélecteur de ville/quartier

### 17. Onboarding — slides illustrations
- Remplacer les emojis (🛒, 🛵, 🏪) par de vraies illustrations SVG (assets/onboarding/)

### 18. Splash — animation
- Logo statique → ajouter Lottie ou rive_animation pour un effet "premium"

### 19. Profil — avatar éditable
- L'éditeur existe via tap mais pas de prévisualisation avant upload
- Pas de crop, pas de compression côté client (upload peut être lourd)

### 20. Notifications — son + vibration custom
- Le payload FCM ne précise pas de channel custom → notif système basique

### 21. Code promo — pas de catalogue
- Le user doit connaître le code à l'avance
- Action : créer `/promos` listant les codes publics actifs (`GET /promo/public`)

### 22. Re-commander — pas de prévisualisation
**Fichier** : `features/client/screens/order/order_history_screen.dart:163-208`

Le bouton "Recommander" écrase directement le panier (avec confirmation). Pas d'écran "Voici les items qui vont être ajoutés" avec possibilité de désélectionner.

### 23. Partage social — deep link non câblé
**Fichier** : `features/client/screens/restaurant/restaurant_screen.dart:38-45`

Le partage utilise `AppConstants.websiteUrl` qui pointe sur le site web. Universal Links / App Links ne sont pas configurés (Android `assetlinks.json`, iOS `apple-app-site-association`).

### 24. Notifications in-app — pas de filtres
**Fichier** : `features/client/screens/notifications/client_notifications_screen.dart`

Toutes les notifs dans une seule liste. Pas de tabs (Commandes / Promotions / Système).

### 25. Empty states — illustrations manquantes
La plupart des écrans utilisent des emojis (📦, 🛒, 😔). À remplacer par des illustrations cohérentes (assets/illustrations/).

---

## 📋 Récap par écran

| Écran | Statut | Bugs |
|---|---|---|
| `/home` | 🔴 cassé | #1, #2, #3, #16 |
| `/search` | 🟡 partiel | #7 |
| `/restaurant/:id` | 🟡 partiel | #13, #14, #15 |
| `/cart` | 🟡 partiel | #9, #10 |
| `/checkout` | 🔴 cassé | #5 |
| `/order/:id` | 🟡 partiel | #6 |
| `/order/:id/review` | ✅ OK | — |
| `/tracking/:orderId` | 🔴 cassé | #4, #12 |
| `/orders` | ✅ OK | #22 (amélioration) |
| `/profile` | 🟡 partiel | #8 (fix dans cette session) |
| `/profile/edit` | ✅ ajouté | — |
| `/addresses` | ✅ OK | #11 (lat/lng) |
| `/notifications` | ✅ OK | #24 |
| `/legal/:type` | ✅ OK | — |

---

## 🛠️ Ordre de priorité recommandé

**Sprint 1 (1-2 jours)** — débloquer le golden path commande :
- [x] #1 Fix crash Home (fait dans cette session)
- [x] #2 Empty/error state Home retry (fait dans cette session)
- [x] #8 Écran /profile/edit (fait dans cette session)
- [ ] #3 Géolocalisation réelle au lieu de Cotonou hardcodé
- [ ] #5 WebView paiement + confirmation
- [ ] #6 CTA "Noter" sur commande livrée
- [ ] #7 Fix tap produit dans recherche

**Sprint 2 (2-3 jours)** — qualité tracking/cart :
- [ ] #4 Tracking statuts dynamiques + ETA réel
- [ ] #9 Panier persistant Hive
- [ ] #10 Calcul frais de livraison
- [ ] #11 Map picker adresses

**Sprint 3 (3-5 jours)** — features secondaires :
- [ ] #12 Messagerie livreur
- [ ] #14 Avis sur fiche resto
- [ ] #15 Produits indisponibles
- [ ] #21 Catalogue promos publiques

**Backlog** — améliorations UX :
- [ ] #16-#25 (illustrations, animations, sons, deep links)
