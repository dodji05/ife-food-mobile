// ─────────────────────────────────────────────────────────────────────────────
// ifè FOOD — Design System unifié
// Charte : Vert #1A6B3C · Jaune #F5C518 · Blanc #FFFFFF
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Palette centralisée ───────────────────────────────────────────────────────
class AppColors {
  // Marque
  static const Color primary      = Color(0xFF1A6B3C);
  static const Color primaryLight = Color(0xFF2E8B57);
  static const Color yellow       = Color(0xFFF5C518);
  static const Color yellowDeep   = Color(0xFFE6A800);

  // Sémantique
  static const Color success      = Color(0xFF10B981);
  static const Color danger       = Color(0xFFEF4444);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color info         = Color(0xFF3B82F6);
  static const Color purple       = Color(0xFF7C3AED);

  // Light mode surfaces
  static const Color lightBg      = Color(0xFFF5F7F5);
  static const Color lightCard    = Color(0xFFFFFFFF);
  static const Color lightBorder  = Color(0xFFE2E8F0);
  static const Color lightSubtext = Color(0xFF7a9e82);
  static const Color nearBlack    = Color(0xFF1A1D1B);

  // Dark mode surfaces
  static const Color darkBg       = Color(0xFF0A1628);
  static const Color darkSurface  = Color(0xFF0F2040);
  static const Color darkCard     = Color(0xFF142A50);
  static const Color darkBorder   = Color(0xFF1E3A6A);
  static const Color darkText     = Color(0xFFE2E8F0);
  static const Color darkSubtext  = Color(0xFF94A3B8);
  static const Color darkMuted    = Color(0xFF334155);

  // Driver-specific dark
  static const Color driverBg     = Color(0xFF0A0F0C);
  static const Color driverCard   = Color(0xFF182019);
  static const Color driverBorder = Color(0xFF243027);
  static const Color driverGreen  = Color(0xFF00C853);

  // Alias sémantiques
  static const Color accent    = yellow;
  static const Color error     = danger;
  static const Color grey      = Color(0xFF9AA89C);
  static const Color lightGrey = Color(0xFFE2E8F0);
  static const Color darkGrey  = Color(0xFF64748B);
  static const Color offWhite  = Color(0xFFF5F7F5);
}

// ── Thème clair (Client · Professionnel par défaut) ───────────────────────────
class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: AppColors.lightBg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary, secondary: AppColors.yellow,
      surface: AppColors.lightCard, background: AppColors.lightBg,
      error: AppColors.danger, onPrimary: Colors.white,
      onSurface: AppColors.nearBlack,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightCard, foregroundColor: AppColors.nearBlack,
      elevation: 0, scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark),
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w800, color: AppColors.nearBlack),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
    )),
    cardTheme: CardTheme(color: AppColors.lightCard, elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.lightCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lightBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      hintStyle: const TextStyle(color: Color(0xFF9AA89C), fontFamily: 'Nunito'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightCard,
      selectedItemColor: AppColors.primary, unselectedItemColor: Color(0xFF9AA89C),
      type: BottomNavigationBarType.fixed, elevation: 0,
      selectedLabelStyle: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontFamily: 'Nunito', fontSize: 11, fontWeight: FontWeight.w500),
    ),
    dividerColor: AppColors.lightBorder,
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.selected) ? AppColors.primary : const Color(0xFF9AA89C)),
      trackColor: MaterialStateProperty.resolveWith((s) =>
        s.contains(MaterialState.selected)
            ? AppColors.primary.withOpacity(0.35) : AppColors.lightBorder),
    ),
  );

  // ── Thème sombre générique ──────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
    useMaterial3: true, brightness: Brightness.dark, fontFamily: 'Nunito',
    scaffoldBackgroundColor: AppColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary, secondary: AppColors.yellow,
      surface: AppColors.darkCard, background: AppColors.darkBg,
      error: AppColors.danger, onPrimary: Colors.white, onSurface: AppColors.darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface, foregroundColor: AppColors.darkText,
      elevation: 0, scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
      titleTextStyle: TextStyle(fontFamily: 'Nunito', fontSize: 20,
          fontWeight: FontWeight.w800, color: AppColors.darkText),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary, foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
    )),
    cardTheme: const CardTheme(color: AppColors.darkCard, elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.darkBorder))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: AppColors.darkCard,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.darkBorder)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      hintStyle: const TextStyle(color: AppColors.darkMuted, fontFamily: 'Nunito'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkSurface, selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.darkMuted, type: BottomNavigationBarType.fixed, elevation: 0,
    ),
    dividerColor: AppColors.darkBorder,
  );

  // ── Thème Livreur (dark électrique) ────────────────────────────────────────
  static ThemeData get driver => dark.copyWith(
    scaffoldBackgroundColor: AppColors.driverBg,
    colorScheme: dark.colorScheme.copyWith(background: AppColors.driverBg),
    cardTheme: CardTheme(color: AppColors.driverCard, elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.driverBorder))),
  );
}
