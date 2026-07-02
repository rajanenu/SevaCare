import 'package:flutter/material.dart';

enum TenantTheme { premium, clinic }

class SevaCareColors {
  SevaCareColors._();

  // ── Warm cream background (oklch(0.985 0.008 90))
  static const Color background = Color(0xFFFAF9F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF4F2EE);
  static const Color glassSurface = Color(0xC7FFFFFF); // rgba(255,255,255,0.78)
  static const Color glassBorder = Color(0xCCE1DEF5);  // rgba(225,222,245,0.80)

  // ── Text
  static const Color text = Color(0xFF1C1A34);
  static const Color textMuted = Color(0xFF6A6882);
  static const Color textOnPrimary = Color(0xFFFAFAF9);

  // ── Primary — deep indigo (oklch(0.52 0.16 268))
  static const Color primary = Color(0xFF5148CC);
  static const Color primaryStrong = Color(0xFF3F39A8);
  static const Color primarySoft = Color(0xFFEEEEFF);

  // ── Mint — teal green (oklch(0.78 0.12 175))
  static const Color mint = Color(0xFF52C499);
  static const Color mintSoft = Color(0xFFE6F8F1);
  static const Color mintForeground = Color(0xFF145240);

  // ── Peach — warm orange (oklch(0.82 0.12 55))
  static const Color peach = Color(0xFFF0A86B);
  static const Color peachSoft = Color(0xFFFEF3E8);
  static const Color peachForeground = Color(0xFF7C3B18);

  // ── Sky — cool blue, used for the IP-Staff persona
  static const Color sky = Color(0xFF4C9FE0);
  static const Color skySoft = Color(0xFFE8F3FC);
  static const Color skyForeground = Color(0xFF1B527D);

  // ── Borders & decorations
  static const Color border = Color(0xFFE5E3F0);
  static const Color overlay = Color(0x145148CC);
  static const Color shadowColor = Color(0xFF3F39A8);

  // ── Semantic
  static const Color success = Color(0xFF3CB878);
  static const Color warning = Color(0xFFE09A30);
  static const Color error = Color(0xFFDB4E2D);
  static const Color danger = Color(0xFFDB4E2D);
  static const Color errorSurface = Color(0xFFFEF2F0);
  static const Color successSurface = Color(0xFFE6F8F1);
  static const Color warningSurface = Color(0xFFFEF8EC);

  // ── Gradients
  static const List<Color> buttonGradient = [Color(0xFF5148CC), Color(0xFF7C6FE0)];
  static const List<Color> heroGradient = [Color(0xFF3F39A8), Color(0xFF7C6FE0)];
  static const List<Color> mintGradient = [Color(0xFF52C499), Color(0xFF3BAE85)];
  static const List<Color> peachGradient = [Color(0xFFF2C072), Color(0xFFE8805A)];
  static const List<Color> skyGradient = [Color(0xFF4C9FE0), Color(0xFF2D6FA8)];
  static const List<Color> dangerGradient = [Color(0xFFDB4E2D), Color(0xFFB83A1E)];
  static const List<Color> screenGradient = [Color(0xFFFAF9F6), Color(0xFFF2F0FA), Color(0xFFF6FAF8)];

  // ── Clinic theme overrides
  static const Color clinicPrimary = Color(0xFF1E8A76);
  static const Color clinicPrimaryStrong = Color(0xFF146659);
  static const Color clinicPrimarySoft = Color(0xFFE6F5F2);
  static const List<Color> clinicButtonGradient = [Color(0xFF1E8A76), Color(0xFF38B2A0)];
  static const List<Color> clinicHeroGradient = [Color(0xFF146659), Color(0xFF1E8A76)];
}

class AppThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color text;
  final Color textMuted;
  final Color textOnPrimary;
  final Color primary;
  final Color primaryStrong;
  final Color primarySoft;
  final Color mint;
  final Color mintSoft;
  final Color mintForeground;
  final Color peach;
  final Color peachSoft;
  final Color peachForeground;
  final Color border;
  final Color error;
  final Color danger;
  final Color success;
  final Color warning;
  final Color errorSurface;
  final Color successSurface;
  final Color warningSurface;
  final List<Color> buttonGradient;
  final List<Color> heroGradient;
  final List<Color> mintGradient;
  final List<Color> peachGradient;

  const AppThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.text,
    required this.textMuted,
    required this.textOnPrimary,
    required this.primary,
    required this.primaryStrong,
    required this.primarySoft,
    required this.mint,
    required this.mintSoft,
    required this.mintForeground,
    required this.peach,
    required this.peachSoft,
    required this.peachForeground,
    required this.border,
    required this.error,
    required this.danger,
    required this.success,
    required this.warning,
    required this.errorSurface,
    required this.successSurface,
    required this.warningSurface,
    required this.buttonGradient,
    required this.heroGradient,
    required this.mintGradient,
    required this.peachGradient,
  });

  static const AppThemeColors premium = AppThemeColors(
    background: SevaCareColors.background,
    surface: SevaCareColors.surface,
    surfaceMuted: SevaCareColors.surfaceMuted,
    text: SevaCareColors.text,
    textMuted: SevaCareColors.textMuted,
    textOnPrimary: SevaCareColors.textOnPrimary,
    primary: SevaCareColors.primary,
    primaryStrong: SevaCareColors.primaryStrong,
    primarySoft: SevaCareColors.primarySoft,
    mint: SevaCareColors.mint,
    mintSoft: SevaCareColors.mintSoft,
    mintForeground: SevaCareColors.mintForeground,
    peach: SevaCareColors.peach,
    peachSoft: SevaCareColors.peachSoft,
    peachForeground: SevaCareColors.peachForeground,
    border: SevaCareColors.border,
    error: SevaCareColors.error,
    danger: SevaCareColors.danger,
    success: SevaCareColors.success,
    warning: SevaCareColors.warning,
    errorSurface: SevaCareColors.errorSurface,
    successSurface: SevaCareColors.successSurface,
    warningSurface: SevaCareColors.warningSurface,
    buttonGradient: SevaCareColors.buttonGradient,
    heroGradient: SevaCareColors.heroGradient,
    mintGradient: SevaCareColors.mintGradient,
    peachGradient: SevaCareColors.peachGradient,
  );

  static const AppThemeColors clinic = AppThemeColors(
    background: SevaCareColors.background,
    surface: SevaCareColors.surface,
    surfaceMuted: SevaCareColors.surfaceMuted,
    text: SevaCareColors.text,
    textMuted: SevaCareColors.textMuted,
    textOnPrimary: SevaCareColors.textOnPrimary,
    primary: SevaCareColors.clinicPrimary,
    primaryStrong: SevaCareColors.clinicPrimaryStrong,
    primarySoft: SevaCareColors.clinicPrimarySoft,
    mint: SevaCareColors.mint,
    mintSoft: SevaCareColors.mintSoft,
    mintForeground: SevaCareColors.mintForeground,
    peach: SevaCareColors.peach,
    peachSoft: SevaCareColors.peachSoft,
    peachForeground: SevaCareColors.peachForeground,
    border: SevaCareColors.border,
    error: SevaCareColors.error,
    danger: SevaCareColors.danger,
    success: SevaCareColors.success,
    warning: SevaCareColors.warning,
    errorSurface: SevaCareColors.errorSurface,
    successSurface: SevaCareColors.successSurface,
    warningSurface: SevaCareColors.warningSurface,
    buttonGradient: SevaCareColors.clinicButtonGradient,
    heroGradient: SevaCareColors.clinicHeroGradient,
    mintGradient: SevaCareColors.mintGradient,
    peachGradient: SevaCareColors.peachGradient,
  );

  static AppThemeColors forTenant(TenantTheme tenant) {
    return tenant == TenantTheme.clinic ? clinic : premium;
  }
}
