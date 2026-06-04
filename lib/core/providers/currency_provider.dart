// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Conversion de devise à l'affichage (client)
//
// Les prix des produits sont stockés en XOF (devise du restaurant). Si le
// client a une autre devise (diaspora : EUR, USD…), on affiche une ESTIMATION
// convertie. La commande/paiement reste en XOF (mobile money) — c'est purement
// cosmétique pour la lisibilité.
//
// Taux récupéré une fois via GET /geo/exchange-rate?from=XOF&to=<devise>,
// mis en cache pour la session.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../api/api_client.dart';
import 'auth_provider.dart';

/// Symboles d'affichage par devise (fallback = code ISO).
const _currencySymbols = <String, String>{
  'XOF': 'F CFA', 'XAF': 'F CFA',
  'EUR': '€', 'USD': '\$', 'GBP': '£', 'CHF': 'CHF', 'CAD': 'C\$',
  'NGN': '₦', 'GHS': '₵', 'KES': 'KSh', 'ZAR': 'R',
  'MAD': 'MAD', 'DZD': 'DA', 'TND': 'DT', 'EGP': 'E£',
};

String currencySymbol(String code) => _currencySymbols[code] ?? code;

/// Devise d'affichage du client (depuis son profil, défaut XOF).
final displayCurrencyProvider = Provider<String>((ref) {
  return ref.watch(authProvider).user?.currency ?? 'XOF';
});

/// Taux XOF → devise du client. 1.0 si XOF ou en cas d'échec (pas de conversion).
final exchangeRateProvider = FutureProvider<double>((ref) async {
  final to = ref.watch(displayCurrencyProvider);
  if (to == 'XOF') return 1.0;
  try {
    final res = await ApiClient.instance.get('/geo/exchange-rate',
        params: {'from': 'XOF', 'to': to});
    final rate = (res['data'] as num?)?.toDouble();
    return (rate != null && rate > 0) ? rate : 1.0;
  } catch (_) {
    return 1.0; // pas de conversion si l'API échoue
  }
});

/// Helper de formatage d'un montant XOF dans la devise d'affichage du client.
class CurrencyFormatter {
  final double rate;
  final String currency;
  const CurrencyFormatter({required this.rate, required this.currency});

  bool get isConverting => currency != 'XOF' && rate != 1.0;

  /// Montant XOF → chaîne formatée dans la devise du client.
  /// Ex (XOF) : "1 000 F CFA" · (EUR) : "≈ 1,52 €"
  String format(double xofAmount) {
    final symbol = currencySymbol(currency);
    if (!isConverting) {
      return '${NumberFormat('#,##0', 'fr').format(xofAmount)} $symbol';
    }
    final converted = xofAmount * rate;
    // 2 décimales pour les devises "fortes", 0 pour XOF/XAF/NGN.
    final decimals = (currency == 'XAF' || currency == 'NGN') ? 0 : 2;
    final formatted = NumberFormat('#,##0.${'0' * decimals}', 'fr').format(converted);
    return '≈ $formatted $symbol';
  }
}

/// Provider du formateur prêt à l'emploi (combine taux + devise).
final currencyFormatterProvider = Provider<CurrencyFormatter>((ref) {
  final rate = ref.watch(exchangeRateProvider).maybeWhen(
    data: (r) => r, orElse: () => 1.0);
  final currency = ref.watch(displayCurrencyProvider);
  return CurrencyFormatter(rate: rate, currency: currency);
});

/// Widget réutilisable : affiche un montant XOF converti dans la devise du
/// client. À utiliser partout où on montrait un prix en dur.
class PriceText extends ConsumerWidget {
  final double amount; // en XOF (devise du restaurant)
  final TextStyle? style;
  const PriceText({super.key, required this.amount, this.style});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatter = ref.watch(currencyFormatterProvider);
    return Text(formatter.format(amount), style: style);
  }
}
