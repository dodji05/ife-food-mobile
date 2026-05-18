// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Sélecteur pays + devise (réutilisable cross-role)
//
// Utilise le package country_picker pour afficher le dialog natif (recherche,
// drapeau, nom localisé). À la sélection :
//   1. Détermine la devise associée au pays (table _countryCurrencyMap)
//   2. PATCH /users/me {countryCode, currency}
//   3. Snackbar de confirmation
//   4. State auth refreshé -> tous les écrans qui lisent user.currency voient
//      le changement (impact futur : affichage prix dynamique XOF -> EUR / USD)
//
// La table couvre les pays cibles UEMOA + CEMAC + quelques EU/US. Pour les
// pays absents, fallback sur USD (assumption raisonnable pour international).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

/// Map countryCode ISO-2 -> devise ISO-3. Couvre principalement zone CFA
/// + grandes devises internationales. Pour les autres pays : fallback USD.
const _countryCurrencyMap = <String, String>{
  // UEMOA (Franc CFA BCEAO - XOF)
  'BJ': 'XOF', 'BF': 'XOF', 'CI': 'XOF', 'GW': 'XOF',
  'ML': 'XOF', 'NE': 'XOF', 'SN': 'XOF', 'TG': 'XOF',
  // CEMAC (Franc CFA BEAC - XAF)
  'CM': 'XAF', 'CF': 'XAF', 'TD': 'XAF', 'CG': 'XAF',
  'GQ': 'XAF', 'GA': 'XAF',
  // Autres pays Afrique
  'NG': 'NGN', 'GH': 'GHS', 'KE': 'KES', 'ZA': 'ZAR',
  'MA': 'MAD', 'DZ': 'DZD', 'TN': 'TND', 'EG': 'EGP',
  // Europe (principaux clients diaspora)
  'FR': 'EUR', 'BE': 'EUR', 'DE': 'EUR', 'IT': 'EUR',
  'ES': 'EUR', 'PT': 'EUR', 'NL': 'EUR', 'IE': 'EUR',
  'CH': 'CHF', 'GB': 'GBP',
  // Amérique du Nord
  'US': 'USD', 'CA': 'CAD',
};

/// Devise correspondant à un pays. Fallback USD si pays inconnu.
String currencyForCountry(String countryCode) {
  return _countryCurrencyMap[countryCode.toUpperCase()] ?? 'USD';
}

/// Affiche le dialog sélecteur de pays. À la sélection, PATCH
/// /users/me {countryCode, currency} et refresh le state auth.
///
/// `darkTheme` : true pour pro/driver (fond sombre du dialog), false pour
/// client (fond clair).
Future<void> showCountryCurrencyPicker(
  BuildContext context,
  WidgetRef ref, {
  required String currentCountryCode,
  bool? darkTheme,
}) async {
  final isDark = darkTheme ?? (Theme.of(context).brightness == Brightness.dark);

  showCountryPicker(
    context: context,
    showPhoneCode: false,
    favorite: const ['BJ', 'CI', 'SN', 'TG', 'FR', 'CA'], // épinglés en haut
    countryListTheme: CountryListThemeData(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      textStyle: TextStyle(
        fontFamily: 'Nunito', fontSize: 14,
        color: isDark ? AppColors.darkText : AppColors.nearBlack,
      ),
      searchTextStyle: TextStyle(
        fontFamily: 'Nunito', fontSize: 14,
        color: isDark ? AppColors.darkText : AppColors.nearBlack,
      ),
      bottomSheetHeight: 500,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      inputDecoration: InputDecoration(
        labelText: 'Rechercher',
        hintText: 'Tapez le nom du pays',
        prefixIcon: const Icon(Icons.search),
        labelStyle: TextStyle(color: isDark ? AppColors.darkSubtext : AppColors.lightSubtext),
      ),
    ),
    onSelect: (Country country) async {
      final code = country.countryCode;
      if (code == currentCountryCode) return; // no-op
      final currency = currencyForCountry(code);

      try {
        await ref.read(authProvider.notifier).completeProfile({
          'countryCode': code,
          'currency':    currency,
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pays : ${country.name} (${country.flagEmoji}) • Devise : $currency'),
          backgroundColor: AppColors.success,
        ));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.danger,
        ));
      }
    },
  );
}
