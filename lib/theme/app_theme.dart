import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  PALETTE CalvoNote
//  Inspirée des savanes du Nord-Cameroun : terre, ocre, nuit
// ─────────────────────────────────────────────────────────────
class AppColors {
  // Fonds
  static const bg         = Color(0xFF0F1117); // nuit profonde
  static const surface    = Color(0xFF1A1D27); // surface cards
  static const card       = Color(0xFF22263A); // card secondaire
  static const cardBorder = Color(0xFF2E3350); // bordure subtile

  // Accents
  static const accent     = Color(0xFFE8873A); // ocre-flamme (bouton principal)
  static const accentGlow = Color(0x33E8873A); // halo enregistrement
  static const fuv        = Color(0xFF4CAF82); // vert Fulfulde (résultat trad)
  static const fuvDim     = Color(0xFF1E3D2F); // fond zone Fulfulde

  // Texte
  static const text       = Color(0xFFEEF0F8);
  static const textMuted  = Color(0xFF7A7F9A);
  static const textFuv    = Color(0xFF6DDFA8); // texte Fulfulde

  // États
  static const ok         = Color(0xFF4CAF82);
  static const error      = Color(0xFFE05555);
  static const warning    = Color(0xFFE8C43A);
  static const recording  = Color(0xFFE84040); // rouge enregistrement
  static const recGlow    = Color(0x44E84040);
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.accent,
        secondary: AppColors.fuv,
        surface:   AppColors.surface,
        error:     AppColors.error,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.w700,
          color: AppColors.text, letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w500,
          color: AppColors.text,
        ),
        bodyLarge: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w400,
          color: AppColors.text, height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontSize: 13, color: AppColors.textMuted, height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600,
          color: AppColors.text, letterSpacing: 0.3,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18, fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        iconTheme: IconThemeData(color: AppColors.textMuted),
      ),
      cardTheme: CardTheme(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14, fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        hintStyle: const TextStyle(color: AppColors.textMuted),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.card,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
