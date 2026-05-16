import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xFF0F0F14); // oklch(15% 0.02 240)
  static const Color surface = Color(0xFF1A1A1F); // oklch(20% 0.02 240)
  static const Color surface2 = Color(0xFF26262B); // oklch(25% 0.02 240)
  static const Color border = Color(0xFF2D2D33); // oklch(30% 0.02 240)
  static const Color fg = Color(0xFFF2F2F7); // oklch(95% 0.005 240)
  static const Color muted = Color(0xFF9999A1); // oklch(60% 0.01 240)
  static const Color accent = Color(0xFFFF3B30); // oklch(65% 0.18 45)
  static const Color accentMuted = Color(0x1FFF3B30); // 12% opacity
  static const Color danger = Color(0xFFD32F2F);
  static const Color success = Color(0xFF4CAF50);
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.8,
          color: AppColors.fg,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.4,
          color: AppColors.fg,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: AppColors.fg),
        bodyMedium: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accent),
      ),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.bg,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    ),
  );

  static TextStyle monoStyle = GoogleFonts.jetBrainsMono(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
  );
}
