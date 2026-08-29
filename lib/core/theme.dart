// Luxury Car Care — warm dark theme.
// Obsidian + mahogany surfaces, burnished gold accent, parchment text.
// Matches the lux-car-care brand palette exactly.

import 'package:flutter/material.dart';

class WashTheme {
  WashTheme._();

  // ── Surfaces ────────────────────────────────────────────────────────────────
  static const Color bg           = Color(0xFF0F0E0D); // obsidian
  static const Color surface      = Color(0xFF1C1917); // mahogany
  static const Color surfaceHigh  = Color(0xFF2A241E); // warm raised surface
  static const Color surfaceCard  = Color(0xFF221E19); // card bg
  static const Color border       = Color(0xFF3A322A); // warm border
  static const Color borderSubtle = Color(0xFF2A2420); // hairline

  // ── Brand Signature ─────────────────────────────────────────────────────────
  static const Color accent       = Color(0xFFC9952A); // burnished gold
  static const Color accentGlow   = Color(0xFFA57A1E); // deep gold (glow / focus)
  static const Color accentLight  = Color(0xFFE8B84B); // lighter gold (hover)

  // ── Semantic ────────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF10B981); // emerald
  static const Color warning      = Color(0xFFF59E0B); // amber
  static const Color danger       = Color(0xFFF43F5E); // rose crimson

  // ── Text ────────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFFFAFAF8); // parchment
  static const Color textSecondary = Color(0xFF9C9489); // warm muted
  static const Color textMuted     = Color(0xFF5C5751); // stone

  // ── Authentic License Plate ─────────────────────────────────────────────────
  static const Color plateYellow = Color(0xFFFFD60A);
  static const Color plateWhite  = Color(0xFFFAFAF8);
  static const Color plateBlue   = Color(0xFF004494);
  static const Color plateBlack  = Color(0xFF0F172A);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentLight,
        surface: surface,
        error: danger,
        onPrimary: bg,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineLarge: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: bg,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(double.infinity, 50),
          side: const BorderSide(color: border, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: borderSubtle, space: 1),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: TextStyle(color: textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
