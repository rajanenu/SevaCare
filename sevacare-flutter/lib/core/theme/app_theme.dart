import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const double radius = 20.0;
  static const double radiusSmall = 12.0;
  static const double radiusPill = 999.0;

  static ThemeData buildTheme(TenantTheme tenant) {
    final colors = AppThemeColors.forTenant(tenant);
    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: colors.text),
      displayMedium: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w700, color: colors.text),
      displaySmall: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: colors.text),
      headlineMedium: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: colors.text),
      titleLarge: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: colors.text),
      titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: colors.text),
      bodyLarge: GoogleFonts.inter(fontSize: 14, color: colors.text),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: colors.textMuted),
      bodySmall: GoogleFonts.inter(fontSize: 11, color: colors.textMuted),
      labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textOnPrimary),
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        primary: colors.primary,
        secondary: colors.mint,
        tertiary: colors.peach,
        surface: colors.surface,
        error: colors.error,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.text,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: colors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: colors.textMuted),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.textOnPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: colors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: colors.border,
      dividerTheme: DividerThemeData(color: colors.border, thickness: 1, space: 0),
    );
  }

  static ThemeData buildDarkTheme() {
    const scaffoldBg = Color(0xFF0F172A);
    const cardBg = Color(0xFF1E293B);
    const borderColor = Color(0xFF334155);
    const textColor = Colors.white;
    const textMutedColor = Color(0xFF94A3B8);
    const primaryColor = Color(0xFF6366F1);

    final textTheme = GoogleFonts.interTextTheme().copyWith(
      displayLarge: GoogleFonts.sora(fontSize: 32, fontWeight: FontWeight.w800, color: textColor),
      displayMedium: GoogleFonts.sora(fontSize: 26, fontWeight: FontWeight.w700, color: textColor),
      displaySmall: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
      headlineMedium: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
      titleLarge: GoogleFonts.sora(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
      titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
      bodyLarge: GoogleFonts.inter(fontSize: 14, color: textColor),
      bodyMedium: GoogleFonts.inter(fontSize: 13, color: textMutedColor),
      bodySmall: GoogleFonts.inter(fontSize: 11, color: textMutedColor),
      labelLarge: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: cardBg,
        error: const Color(0xFFEF4444),
        brightness: Brightness.dark,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: cardBg,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.sora(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: textMutedColor),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textMutedColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: borderColor, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerColor: borderColor,
      dividerTheme: const DividerThemeData(color: borderColor, thickness: 1, space: 0),
    );
  }
}
