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
  String fmt(double v) => '${v.toStringAsFixed(0)} F';
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
              pw.Text(fmt(item.totalPrice), style: styleBody),
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
          pw.Text(fmt(order.subtotal), style: styleBody),
        ]),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Text('Livraison', style: styleBody),
          pw.Spacer(),
          pw.Text(fmt(order.deliveryFee), style: styleBody),
        ]),
        if (order.promoDiscount > 0) ...[
          pw.SizedBox(height: 3),
          pw.Row(children: [
            pw.Text('Réduction', style: styleBody),
            pw.Spacer(),
            pw.Text('-${fmt(order.promoDiscount)}', style: styleBody),
          ]),
        ],
        if (order.tipAmount > 0) ...[
          pw.SizedBox(height: 3),
          pw.Row(children: [
            pw.Text('Pourboire', style: styleBody),
            pw.Spacer(),
            pw.Text(fmt(order.tipAmount), style: styleBody),
          ]),
        ],
        pw.SizedBox(height: 4),
        sep,
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Text('TOTAL', style: styleBold),
          pw.Spacer(),
          pw.Text(fmt(order.totalAmount), style: styleBold),
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
