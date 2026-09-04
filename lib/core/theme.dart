// Luxury Car Care — brand theme, light and dark.
//
// Colours live in [WashColors], a ThemeExtension registered on both ThemeData
// objects. Read them from a widget with `context.wash.accent` — that registers
// a dependency on the inherited Theme, so every widget repaints when the user
// flips the toggle.
//
// Do NOT reintroduce static colour constants for anything that differs between
// the two themes; a `const` colour cannot follow the theme. The only constants
// left here are the licence-plate colours, which are real-world colours and
// are deliberately identical in both modes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

@immutable
class WashColors extends ThemeExtension<WashColors> {
  // ── Surfaces ───────────────────────────────────────────────────────────────
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceCard;
  final Color border;
  final Color borderSubtle;

  // ── Brand signature ────────────────────────────────────────────────────────
  final Color accent;
  final Color accentGlow;
  final Color accentLight;

  /// Foreground colour for content sitting *on top of* an [accent] fill
  /// (button labels, spinners inside gold buttons).
  final Color onAccent;

  // ── Semantic ───────────────────────────────────────────────────────────────
  final Color success;
  final Color warning;
  final Color danger;

  // ── Text ───────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Drop-shadow tint. Near-black in dark mode, warmer and softer in light mode
  /// where a hard black shadow reads as dirt.
  final Color shadow;

  const WashColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceCard,
    required this.border,
    required this.borderSubtle,
    required this.accent,
    required this.accentGlow,
    required this.accentLight,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.shadow,
  });

  /// Obsidian + mahogany surfaces, burnished gold accent, parchment text.
  static const WashColors dark = WashColors(
    bg: Color(0xFF0F0E0D), // obsidian
    surface: Color(0xFF1C1917), // mahogany
    surfaceHigh: Color(0xFF2A241E), // warm raised surface
    surfaceCard: Color(0xFF221E19), // card bg
    border: Color(0xFF3A322A), // warm border
    borderSubtle: Color(0xFF2A2420), // hairline
    accent: Color(0xFFC9952A), // burnished gold
    accentGlow: Color(0xFFA57A1E), // deep gold (glow / focus)
    accentLight: Color(0xFFE8B84B), // lighter gold (hover)
    onAccent: Color(0xFF0F0E0D),
    success: Color(0xFF10B981), // emerald
    warning: Color(0xFFF59E0B), // amber
    danger: Color(0xFFF43F5E), // rose crimson
    textPrimary: Color(0xFFFAFAF8), // parchment
    textSecondary: Color(0xFF9C9489), // warm muted
    textMuted: Color(0xFF7D766E), // stone — was 0xFF5C5751 (2.7:1, below AA)
    shadow: Color(0xFF000000),
  );

  /// Warm ivory paper, deepened gold so it stays legible on a light ground.
  /// Every text colour here clears WCAG AA (4.5:1) against both [bg] and
  /// [surfaceCard]. Re-check contrast before changing any of these.
  static const WashColors light = WashColors(
    bg: Color(0xFFFBFAF7), // warm ivory
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1ECE3), // warm raised surface / input fill
    surfaceCard: Color(0xFFFFFFFF),
    border: Color(0xFFE4DBCC), // warm border
    borderSubtle: Color(0xFFEFEAE1), // hairline
    accent: Color(0xFF8A6410), // deepened gold — 5.1:1 on ivory
    accentGlow: Color(0xFFA57A1E),
    accentLight: Color(0xFF6E4F0B), // hover goes *darker* on a light ground
    onAccent: Color(0xFFFFFFFF),
    success: Color(0xFF04785A),
    warning: Color(0xFFA65B08),
    danger: Color(0xFFBE123C),
    textPrimary: Color(0xFF1C1917),
    textSecondary: Color(0xFF615952),
    textMuted: Color(0xFF78706A),
    shadow: Color(0xFF57493A), // warm brown-grey, not black
  );

  @override
  WashColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHigh,
    Color? surfaceCard,
    Color? border,
    Color? borderSubtle,
    Color? accent,
    Color? accentGlow,
    Color? accentLight,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? shadow,
  }) {
    return WashColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      surfaceCard: surfaceCard ?? this.surfaceCard,
      border: border ?? this.border,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      accent: accent ?? this.accent,
      accentGlow: accentGlow ?? this.accentGlow,
      accentLight: accentLight ?? this.accentLight,
      onAccent: onAccent ?? this.onAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  WashColors lerp(ThemeExtension<WashColors>? other, double t) {
    if (other is! WashColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return WashColors(
      bg: mix(bg, other.bg),
      surface: mix(surface, other.surface),
      surfaceHigh: mix(surfaceHigh, other.surfaceHigh),
      surfaceCard: mix(surfaceCard, other.surfaceCard),
      border: mix(border, other.border),
      borderSubtle: mix(borderSubtle, other.borderSubtle),
      accent: mix(accent, other.accent),
      accentGlow: mix(accentGlow, other.accentGlow),
      accentLight: mix(accentLight, other.accentLight),
      onAccent: mix(onAccent, other.onAccent),
      success: mix(success, other.success),
      warning: mix(warning, other.warning),
      danger: mix(danger, other.danger),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// `context.wash.accent` — the supported way to read a brand colour.
extension WashColorsContext on BuildContext {
  WashColors get wash =>
      Theme.of(this).extension<WashColors>() ?? WashColors.dark;
}

class WashTheme {
  WashTheme._();

  // ── Authentic licence plate ────────────────────────────────────────────────
  // Real-world colours. Identical in both themes on purpose — an Indian plate
  // is yellow-on-black whatever the app's theme happens to be.
  static const Color plateYellow = Color(0xFFFFD60A);
  static const Color plateWhite = Color(0xFFFAFAF8);
  static const Color plateBlue = Color(0xFF004494);
  static const Color plateBlack = Color(0xFF0F172A);

  static ThemeData dark() => _build(WashColors.dark, Brightness.dark);

  static ThemeData light() => _build(WashColors.light, Brightness.light);

  static ThemeData _build(WashColors c, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: c.bg,
      fontFamily: 'Inter',
      extensions: <ThemeExtension<dynamic>>[c],
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.accent,
        onPrimary: c.onAccent,
        secondary: c.accentLight,
        onSecondary: c.onAccent,
        surface: c.surface,
        onSurface: c.textPrimary,
        error: c.danger,
        onError: isDark ? c.bg : const Color(0xFFFFFFFF),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: c.textPrimary),
        // Status-bar icons have to invert with the theme, otherwise light mode
        // shows white-on-white icons.
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: c.bg,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
        headlineLarge: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        // Was missing before: `titleMedium` is used on the save-wash screen and
        // was silently falling back to the Material default.
        titleMedium: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 15,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: c.textSecondary,
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      iconTheme: IconThemeData(color: c.textPrimary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.onAccent,
          disabledBackgroundColor: c.surfaceHigh,
          disabledForegroundColor: c.textMuted,
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
          foregroundColor: c.textPrimary,
          minimumSize: const Size(double.infinity, 50),
          side: BorderSide(color: c.border, width: 1.2),
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
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.danger),
        ),
        labelStyle: TextStyle(color: c.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: c.textMuted, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: TextStyle(
          color: c.textPrimary,
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: c.textSecondary,
          fontFamily: 'Inter',
          fontSize: 14,
          height: 1.4,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceCard,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: c.textPrimary, fontFamily: 'Inter'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: c.border),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceCard,
        surfaceTintColor: Colors.transparent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
      dividerTheme: DividerThemeData(color: c.borderSubtle, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: TextStyle(color: c.textPrimary, fontFamily: 'Inter'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
