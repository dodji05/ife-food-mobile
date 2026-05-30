// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Sélecteur de langue (réutilisable cross-role)
//
// Bottom sheet listant les 7 langues supportées (alignées avec
// supportedLocales de MaterialApp + l'enum Language Prisma backend).
//
// Usage :
//   await showLanguagePicker(context, ref, currentLang: user.lang);
//
// La sélection déclenche :
//   1. PATCH /users/me {lang} via authProvider.completeProfile()
//   2. Snackbar de confirmation
//   3. State auth refreshé -> les écrans qui watch authProvider verront
//      la nouvelle valeur user.lang
//
// ⚠️ Pour i18n EFFECTIF des labels UI (vs. labels backend localisés via
// product.localizedName), il faut setup intl + .arb (TIER 2 v2 -- pour
// l'instant ça change juste la préférence stockée + le backend retourne
// les contenus dans la bonne langue).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_colors.dart';

const supportedLanguages = <Map<String, String>>[
  {'code': 'fr', 'label': 'Français',  'flag': '🇫🇷'},
  {'code': 'en', 'label': 'English',   'flag': '🇬🇧'},
  {'code': 'es', 'label': 'Español',   'flag': '🇪🇸'},
  {'code': 'de', 'label': 'Deutsch',   'flag': '🇩🇪'},
  {'code': 'ru', 'label': 'Русский',   'flag': '🇷🇺'},
  {'code': 'ar', 'label': 'العربية',   'flag': '🇸🇦'},
  {'code': 'zh', 'label': '中文',       'flag': '🇨🇳'},
];

/// Retourne le label localisé d'une langue depuis son code (ex: 'fr' -> 'Français').
/// Fallback sur le code lui-même si inconnu.
String languageLabel(String code) {
  final entry = supportedLanguages.firstWhere(
    (l) => l['code'] == code,
    orElse: () => {'label': code.toUpperCase()},
  );
  return entry['label']!;
}

/// Affiche le bottom sheet et applique la sélection. Sans effet si l'user
/// annule ou choisit la langue déjà active.
///
/// `darkTheme` : true pour styling sombre (pro/driver), false pour clair
/// (client). Par défaut détecte via Theme.of(context).brightness.
Future<void> showLanguagePicker(
  BuildContext context,
  WidgetRef ref, {
  required String currentLang,
  bool? darkTheme,
}) async {
  final textColor = context.textPrimary;
  final dividerColor = context.borderColor;

  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: dividerColor, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(alignment: Alignment.centerLeft, child: Text(
            'Choisir une langue',
            style: TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800, color: textColor),
          )),
        ),
        ...supportedLanguages.map((l) {
          final isCurrent = l['code'] == currentLang;
          return ListTile(
            leading: Text(l['flag']!, style: const TextStyle(fontSize: 22)),
            title: Text(
              l['label']!,
              style: TextStyle(
                fontFamily: 'Nunito', fontSize: 15,
                fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
                color: isCurrent ? AppColors.primary : textColor,
              ),
            ),
            trailing: isCurrent
                ? const Icon(Icons.check_rounded, color: AppColors.primary)
                : null,
            onTap: () => Navigator.pop(context, l['code']),
          );
        }),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (picked == null || picked == currentLang) return;

  try {
    await ref.read(authProvider.notifier).completeProfile({'lang': picked});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Langue mise à jour : ${languageLabel(picked)}'),
      backgroundColor: AppColors.success,
    ));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(e.toString().replaceAll('Exception: ', '')),
      backgroundColor: AppColors.danger,
    ));
  }
}
