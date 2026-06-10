// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Extension ThemeX sur BuildContext
//
// Fournit des couleurs sémantiques réactives au thème actif (light / dark).
// Le thème est unifié pour tous les rôles dans main.dart :
//   - Clair  : AppTheme.light  (tous rôles)
//   - Sombre : AppTheme.dark   (tous rôles — navy)
//
// Usage dans les widgets :
//   backgroundColor: context.bgColor
//   color:           context.cardColor
//   color:           context.borderColor
//   color:           context.textPrimary
//   color:           context.textSecondary
//   color:           context.textMuted
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'app_theme.dart';

extension ThemeX on BuildContext {
  ThemeData get _t => Theme.of(this);

  bool get isDark => _t.brightness == Brightness.dark;

  // ── Backgrounds ──────────────────────────────────────────────────────────
  /// Fond principal de l'écran — suit scaffoldBackgroundColor du thème actif.
  Color get bgColor => _t.scaffoldBackgroundColor;

  /// Fond des cartes / containers — suit cardTheme.color du thème actif.
  Color get cardColor => _t.cardTheme.color ?? _t.colorScheme.surface;

  // ── Bordures ─────────────────────────────────────────────────────────────
  /// Couleur de bordure — suit dividerColor (configuré par rôle dans AppTheme).
  Color get borderColor => _t.dividerColor;

  // ── Texte ─────────────────────────────────────────────────────────────────
  /// Texte principal (titres, labels importants).
  Color get textPrimary => _t.colorScheme.onSurface;

  /// Texte secondaire (sous-titres, descriptions).
  Color get textSecondary =>
      isDark ? AppColors.darkSubtext : AppColors.lightSubtext;

  /// Texte très atténué (placeholders, métadonnées).
  Color get textMuted => isDark ? AppColors.darkMuted : AppColors.grey;

  // ── Surfaces ─────────────────────────────────────────────────────────────
  /// Fond des AppBar / headers — suit appBarTheme.backgroundColor du thème actif.
  Color get surfaceColor => _t.appBarTheme.backgroundColor ?? cardColor;
}
