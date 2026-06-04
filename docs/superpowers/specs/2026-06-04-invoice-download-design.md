# Design — Facture téléchargeable par commande

**Date :** 2026-06-04  
**Projet :** IFE FOOD — Mobile Flutter  
**Scope :** Génération et partage d'un reçu PDF pour chaque commande payée

---

## Contexte

Le client doit pouvoir télécharger une facture (reçu) pour toute commande dont le paiement est confirmé (`order.isPaid` = `paymentStatus == 'SUCCESS'`). Le téléchargement est disponible dès le paiement et pour toujours, y compris après livraison.

---

## Décisions clés

| Question | Décision |
|----------|----------|
| Quand disponible ? | Dès `isPaid`, pour toujours (PAID → DELIVERED inclus) |
| Où généré ? | Côté mobile uniquement (pas de backend) |
| Format | PDF format reçu (pas A4) |
| Où affiché ? | Carte liste + écran détail |
| Méthode partage | `share_plus` (déjà installé) |

---

## Architecture

### Nouveau fichier

**`lib/core/utils/invoice_generator.dart`**

Fonction publique unique :
```dart
Future<void> generateAndShareInvoice(Order order) async
```

Responsabilités :
1. Construire un `pw.Document` (package `pdf`) au format reçu
2. Sauvegarder en fichier temporaire via `path_provider` (`getTemporaryDirectory()`)
3. Déclencher `Share.shareXFiles([XFile(path)])` via `share_plus`

Aucun provider, aucun état global, aucun écran supplémentaire.

---

## Contenu du reçu PDF

```
═══════════════════════
       IFE FOOD
   Reçu de commande
═══════════════════════
Commande : #<id court>
Date     : JJ/MM/AAAA HH:mm
Restaurant : <professionalName>
───────────────────────
<qty>x <productName>    <prix> F
...
───────────────────────
Sous-total          XXXX F
Livraison            XXX F
TOTAL               XXXX F
───────────────────────
Paiement : <paymentMethod>  ✓
Statut   : Payé
═══════════════════════
     Merci de votre confiance
```

- Largeur de page : 200 × 400pt (format reçu étroit, pas A4)
- Marges : 16pt partout
- Polices : `pw.Font.helveticaBold` pour les titres, `pw.Font.helvetica` pour le corps
- Nom du fichier : `facture_ife_<orderId_court>.pdf`

---

## Intégration UI

### 1. Carte commande (`order_history_screen.dart` — `_OrderCard`)

- Condition d'affichage : `order.isPaid` (inclut tous les statuts post-paiement)
- Widget : `OutlinedButton.icon` avec `Icons.receipt_long_rounded`
- Label : `"Facture"`
- Taille : `minimumSize: Size(80, 32)`, même style que les autres boutons de la carte
- Position : tout à gauche dans la `Row` des boutons (avant "Avis" et "Recommander")
- État chargement : `CircularProgressIndicator` de 14px pendant la génération

### 2. Écran détail (`order_detail_screen.dart`)

- Condition d'affichage : `order.isPaid`
- Widget : `ElevatedButton.icon` avec `Icons.download_rounded`
- Label : `"Télécharger la facture"`
- Position : dans la section bas de l'écran, sous les infos de paiement
- État chargement : bouton désactivé + spinner pendant la génération

---

## Packages à ajouter (`pubspec.yaml`)

```yaml
pdf: ^3.10.8
path_provider: ^2.1.2
```

`share_plus` est déjà présent.

---

## Gestion d'erreur

- Si la génération échoue → `ScaffoldMessenger` snackbar rouge "Erreur lors de la génération de la facture"
- Pas de retry automatique

---

## Hors scope

- Génération côté backend / stockage serveur
- Envoi automatique par email
- Historique des factures téléchargées
- Personnalisation du logo restaurant dans le PDF
