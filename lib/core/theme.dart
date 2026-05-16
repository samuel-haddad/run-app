import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color bg = Color(0xFF040C13); // Fundo externo (Display)
  static const Color surface = Color(0xFF0E171E); // Área do App (Corpo)
  static const Color surface2 = Color(0xFF16212B); 
  static const Color border = Color(0xFF1C2834); 
  static const Color fg = Colors.white;
  static const Color muted = Color(0xFF64748B);
  static const Color accent = Color(0xFFE6671A); // Laranja vibrante
  static const Color accentMuted = Color(0x26E6671A);
  static const Color danger = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.surface, // O app em si usa a cor de área
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    // Fonte Principal: Inter
    textTheme: GoogleFonts.interTextTheme(
      const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.fg,
          letterSpacing: -0.8,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.fg,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: AppColors.fg, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: AppColors.muted),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bg,
      labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
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
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );

  // Fonte Técnica: JetBrains Mono
  static TextStyle monoStyle = GoogleFonts.jetBrainsMono(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.0,
  );
}
