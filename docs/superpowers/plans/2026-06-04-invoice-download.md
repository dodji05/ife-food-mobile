# Invoice Download Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Permettre au client de télécharger un reçu PDF pour chaque commande dont le paiement est confirmé, depuis la carte liste ET l'écran détail.

**Architecture:** Un utilitaire `invoice_generator.dart` génère un PDF format reçu (200×400pt) avec le package `pdf`, le sauvegarde dans le répertoire temporaire via `path_provider`, puis déclenche le partage natif via `share_plus`. Deux intégrations UI : bouton "Facture" sur `_OrderCard` et bouton "Télécharger la facture" dans `order_detail_screen.dart`.

**Tech Stack:** Flutter, `pdf ^3.10.8`, `path_provider ^2.1.2`, `share_plus` (déjà installé)

---

## Structure des fichiers

| Action | Fichier | Rôle |
|--------|---------|------|
| Créer | `lib/core/utils/invoice_generator.dart` | Génération PDF + partage |
| Modifier | `pubspec.yaml` | Ajouter `pdf` et `path_provider` |
| Modifier | `lib/features/client/screens/order/order_history_screen.dart` | Bouton "Facture" sur `_OrderCard` |
| Modifier | `lib/features/client/screens/order/order_detail_screen.dart` | Bouton "Télécharger la facture" |

---

## Task 1 : Ajouter les dépendances

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1 : Ajouter `pdf` et `path_provider` dans `pubspec.yaml`**

Ouvrir `pubspec.yaml`. Dans la section `dependencies:`, après la ligne `share_plus: ^7.2.2`, ajouter :

```yaml
  pdf: ^3.10.8
  path_provider: ^2.1.2
```

- [ ] **Step 2 : Installer les dépendances**

```bash
cd "MOBILE Serveur"
flutter pub get
```

Sortie attendue : `Got dependencies!` (pas d'erreur)

- [ ] **Step 3 : Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore: add pdf and path_provider for invoice generation"
```

---

## Task 2 : Créer l'utilitaire `invoice_generator.dart`

**Files:**
- Create: `lib/core/utils/invoice_generator.dart`

- [ ] **Step 1 : Créer le fichier**

Créer `lib/core/utils/invoice_generator.dart` avec le contenu suivant :

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../shared/models/order.dart';

/// Génère un reçu PDF pour [order] et ouvre la feuille de partage native.
/// Ne doit être appelé que si [order.isPaid] est true.
Future<void> generateAndShareInvoice(Order order) async {
  final doc = pw.Document();

  // ── Dimensions format reçu ─────────────────────────────────────────
  const pageFormat = PdfPageFormat(200, 400, marginAll: 16);

  // ── Styles ────────────────────────────────────────────────────────
  final styleTitle = pw.TextStyle(
    font: pw.Font.helveticaBold(),
    fontSize: 13,
  );
  final styleBody = pw.TextStyle(
    font: pw.Font.helvetica(),
    fontSize: 9,
  );
  final styleBold = pw.TextStyle(
    font: pw.Font.helveticaBold(),
    fontSize: 9,
  );
  final styleSmall = pw.TextStyle(
    font: pw.Font.helvetica(),
    fontSize: 8,
  );

  // ── Helpers ───────────────────────────────────────────────────────
  String _fmt(double v) => '${v.toStringAsFixed(0)} F';
  final shortId = (order.id.length >= 8 ? order.id.substring(0, 8) : order.id).toUpperCase();
  final date =
      '${order.createdAt.day.toString().padLeft(2, '0')}/${order.createdAt.month.toString().padLeft(2, '0')}/${order.createdAt.year}  ${order.createdAt.hour.toString().padLeft(2, '0')}h${order.createdAt.minute.toString().padLeft(2, '0')}';

  // ── Séparateurs ───────────────────────────────────────────────────
  final sep = pw.Divider(color: PdfColors.grey400, thickness: 0.5);
  const gap = pw.SizedBox(height: 4);

  doc.addPage(pw.Page(
    pageFormat: pageFormat,
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // ── En-tête ──────────────────────────────────────────────
        pw.Text('IFE FOOD', style: styleTitle),
        gap,
        pw.Text('Reçu de commande', style: styleBody),
        pw.SizedBox(height: 8),
        sep,
        pw.SizedBox(height: 6),

        // ── Infos commande ───────────────────────────────────────
        pw.Row(children: [
          pw.Text('Commande :', style: styleSmall),
          pw.Spacer(),
          pw.Text('#$shortId', style: styleBold),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Date :', style: styleSmall),
          pw.Spacer(),
          pw.Text(date, style: styleSmall),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Restaurant :', style: styleSmall),
          pw.Spacer(),
          pw.Flexible(
            child: pw.Text(
              order.professionalName,
              style: styleSmall,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ]),
        pw.SizedBox(height: 8),
        sep,
        pw.SizedBox(height: 6),

        // ── Lignes articles ──────────────────────────────────────
        ...order.items.map((item) {
          final name = item.productName.isNotEmpty
              ? item.productName
              : (item.product?['name']?['fr'] as String? ?? 'Produit');
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(children: [
              pw.Text('${item.quantity}×', style: styleBold),
              pw.SizedBox(width: 4),
              pw.Expanded(child: pw.Text(name, style: styleBody)),
              pw.Text(_fmt(item.totalPrice), style: styleBody),
            ]),
          );
        }),

        pw.SizedBox(height: 6),
        sep,
        pw.SizedBox(height: 6),

        // ── Totaux ───────────────────────────────────────────────
        pw.Row(children: [
          pw.Text('Sous-total', style: styleBody),
          pw.Spacer(),
          pw.Text(_fmt(order.subtotal), style: styleBody),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Livraison', style: styleBody),
          pw.Spacer(),
          pw.Text(_fmt(order.deliveryFee), style: styleBody),
        ]),
        if (order.promoDiscount > 0) ...[
          pw.SizedBox(height: 3),
          pw.Row(children: [
            pw.Text('Réduction', style: styleBody),
            pw.Spacer(),
            pw.Text('-${_fmt(order.promoDiscount)}', style: styleBody),
          ]),
        ],
        if (order.tipAmount > 0) ...[
          pw.SizedBox(height: 3),
          pw.Row(children: [
            pw.Text('Pourboire', style: styleBody),
            pw.Spacer(),
            pw.Text(_fmt(order.tipAmount), style: styleBody),
          ]),
        ],
        pw.SizedBox(height: 4),
        sep,
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Text('TOTAL', style: styleBold),
          pw.Spacer(),
          pw.Text(_fmt(order.totalAmount), style: styleBold),
        ]),
        pw.SizedBox(height: 8),
        sep,
        pw.SizedBox(height: 6),

        // ── Paiement ─────────────────────────────────────────────
        pw.Row(children: [
          pw.Text('Statut paiement :', style: styleSmall),
          pw.Spacer(),
          pw.Text('Payé ✓', style: styleBold),
        ]),
        pw.SizedBox(height: 10),
        sep,
        pw.SizedBox(height: 8),

        // ── Pied ─────────────────────────────────────────────────
        pw.Text('Merci de votre confiance !', style: styleSmall),
      ],
    ),
  ));

  // ── Sauvegarde + partage ───────────────────────────────────────────
  final bytes = await doc.save();
  final dir = await getTemporaryDirectory();
  final fileName = 'facture_ife_$shortId.pdf';
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);

  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'application/pdf')],
    subject: 'Facture IFE FOOD — Commande #$shortId',
  );
}
```

- [ ] **Step 2 : Vérifier que le projet compile**

```bash
flutter analyze lib/core/utils/invoice_generator.dart
```

Sortie attendue : `No issues found!` ou seulement des infos/warnings mineurs (pas d'erreurs rouges).

- [ ] **Step 3 : Commit**

```bash
git add lib/core/utils/invoice_generator.dart
git commit -m "feat: add invoice_generator utility (PDF receipt + share)"
```

---

## Task 3 : Bouton "Facture" dans la carte commande

**Files:**
- Modify: `lib/features/client/screens/order/order_history_screen.dart`

Contexte : le widget `_OrderCardState` contient un champ `bool _reordering`. Il faut ajouter `bool _generatingInvoice = false;` et le bouton dans la `Row` des actions.

- [ ] **Step 1 : Ajouter le champ d'état et l'import dans `_OrderCardState`**

En haut du fichier `order_history_screen.dart`, ajouter l'import :

```dart
import '../../../../core/utils/invoice_generator.dart';
```

Dans `_OrderCardState`, après la ligne `bool _reordering = false;`, ajouter :

```dart
bool _generatingInvoice = false;
```

- [ ] **Step 2 : Ajouter la méthode `_downloadInvoice`**

Dans `_OrderCardState`, après la méthode `_reorder()`, ajouter :

```dart
Future<void> _downloadInvoice() async {
  setState(() => _generatingInvoice = true);
  try {
    await generateAndShareInvoice(widget.order);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Erreur lors de la génération de la facture'),
      backgroundColor: Colors.red,
    ));
  } finally {
    if (mounted) setState(() => _generatingInvoice = false);
  }
}
```

- [ ] **Step 3 : Ajouter le bouton "Facture" dans la Row des actions**

Dans `_OrderCardState.build`, localiser la `Row` qui contient `const Spacer()` (début de la zone boutons). **Après** `const Spacer()`, insérer le bouton facture **avant** les autres boutons existants. Remplacer le bloc `Row(children: [` existant par :

```dart
Row(children: [
  const Spacer(),
  // Bouton facture (dès que le paiement est confirmé)
  if (order.isPaid) ...[
    OutlinedButton.icon(
      onPressed: _generatingInvoice ? null : _downloadInvoice,
      icon: _generatingInvoice
          ? const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : const Icon(Icons.receipt_long_rounded, size: 14),
      label: const Text('Facture',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        side: const BorderSide(color: AppColors.primary),
      ),
    ),
    const SizedBox(width: 8),
  ],
  // Bouton avis (livré, pas encore d'avis)
  if (order.isDelivered && !order.hasReview) ...[
    OutlinedButton.icon(
      onPressed: () => context.push('/order/${order.id}/review'),
      icon: const Icon(Icons.star_rounded, size: 14),
      label: const Text('Avis', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(80, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        foregroundColor: AppColors.warning,
        side: const BorderSide(color: AppColors.warning),
      ),
    ),
    const SizedBox(width: 8),
  ],
  if (order.isDelivered) OutlinedButton(
    onPressed: _reordering ? null : _reorder,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(110, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      side: const BorderSide(color: AppColors.primary),
    ),
    child: _reordering
        ? const SizedBox(width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
        : const Text('Recommander', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
  ),
  if (order.isActive) ElevatedButton(
    onPressed: () => context.push('/tracking/${order.id}'),
    style: ElevatedButton.styleFrom(
      minimumSize: const Size(80, 32),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    child: const Text('Suivre', style: TextStyle(fontFamily: 'Nunito', fontSize: 12)),
  ),
]),
```

- [ ] **Step 4 : Vérifier que le projet compile**

```bash
flutter analyze lib/features/client/screens/order/order_history_screen.dart
```

Sortie attendue : `No issues found!`

- [ ] **Step 5 : Commit**

```bash
git add lib/features/client/screens/order/order_history_screen.dart
git commit -m "feat: add invoice download button to order card"
```

---

## Task 4 : Bouton "Télécharger la facture" dans l'écran détail

**Files:**
- Modify: `lib/features/client/screens/order/order_detail_screen.dart`

Contexte : `_OrderDetailScreenState` est un `ConsumerStatefulWidget` avec `WidgetsBindingObserver`. Le body est un `ListView`. La fin du contenu (avant `const SizedBox(height: 40)` et la fermeture `]);`) se trouve après la `_Card` de livraison.

- [ ] **Step 1 : Ajouter l'import et le champ d'état**

En haut de `order_detail_screen.dart`, ajouter l'import :

```dart
import '../../../../core/utils/invoice_generator.dart';
```

Dans `_OrderDetailScreenState`, après `bool _checking = false;`, ajouter :

```dart
bool _generatingInvoice = false;
```

- [ ] **Step 2 : Ajouter la méthode `_downloadInvoice`**

Dans `_OrderDetailScreenState`, après la méthode `_stopPolling()`, ajouter :

```dart
Future<void> _downloadInvoice(Order order) async {
  setState(() => _generatingInvoice = true);
  try {
    await generateAndShareInvoice(order);
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Erreur lors de la génération de la facture'),
      backgroundColor: Colors.red,
    ));
  } finally {
    if (mounted) setState(() => _generatingInvoice = false);
  }
}
```

- [ ] **Step 3 : Ajouter le bouton dans le ListView**

Dans le `build`, localiser la ligne :
```dart
          const SizedBox(height: 40),
```
(c'est le dernier `SizedBox` avant la fermeture `]);`). **Avant** cette ligne, insérer le bouton facture :

```dart
          // Bouton facture (dès que paiement confirmé)
          if (o.isPaid) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generatingInvoice ? null : () => _downloadInvoice(o),
                icon: _generatingInvoice
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _generatingInvoice ? 'Génération...' : 'Télécharger la facture',
                  style: const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
```

- [ ] **Step 4 : Vérifier que le projet compile**

```bash
flutter analyze lib/features/client/screens/order/order_detail_screen.dart
```

Sortie attendue : `No issues found!`

- [ ] **Step 5 : Commit et push**

```bash
git add lib/features/client/screens/order/order_detail_screen.dart
git commit -m "feat: add invoice download button to order detail screen"
git push
```

---

## Vérification manuelle après déploiement

1. Aller dans **Mes commandes** → tab "Livrées" (ou "Toutes" avec une commande PAID)
2. Vérifier que le bouton **"Facture"** apparaît à gauche de "Recommander"
3. Tapper "Facture" → la feuille de partage native s'ouvre avec un fichier `facture_ife_XXXXXXXX.pdf`
4. Ouvrir le PDF → vérifier : nom restaurant, liste articles, totaux, statut "Payé ✓"
5. Aller dans **Détail d'une commande payée** → vérifier le bouton "Télécharger la facture" en bas
6. Vérifier qu'une commande **annulée** (non payée) n'a PAS le bouton facture
7. Vérifier qu'une commande **en cours de paiement** (PENDING) n'a PAS le bouton facture
