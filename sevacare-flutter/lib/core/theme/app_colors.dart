import 'package:flutter/material.dart';

enum TenantTheme { premium, clinic }

/// Raw brand palette. These are the *source* constants — light-mode values used
/// for const contexts and as the seed for [AppThemeColors]. Screens should read
/// colours through `context.colors` (theme- and brightness-aware), not these
/// directly, so a screen renders correctly in dark mode without edits.
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

/// Brightness- and tenant-aware colour set, exposed as a [ThemeExtension] so a
/// single access point (`context.colors`) returns the right value for the
/// active theme. Read this in widgets instead of [SevaCareColors] — that is what
/// makes dark mode actually work.
@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Brightness brightness;

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color glassSurface;
  final Color glassBorder;

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

  final Color sky;
  final Color skySoft;
  final Color skyForeground;

  final Color border;
  final Color overlay;
  final Color shadowColor;

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
  final List<Color> skyGradient;
  final List<Color> dangerGradient;
  final List<Color> screenGradient;

  const AppThemeColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.glassSurface,
    required this.glassBorder,
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
    required this.sky,
    required this.skySoft,
    required this.skyForeground,
    required this.border,
    required this.overlay,
    required this.shadowColor,
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
    required this.skyGradient,
    required this.dangerGradient,
    required this.screenGradient,
  });

  bool get isDark => brightness == Brightness.dark;

  // ── Light: premium (indigo) ───────────────────────────────────────────────
  static const AppThemeColors premium = AppThemeColors(
    brightness: Brightness.light,
    background: SevaCareColors.background,
    surface: SevaCareColors.surface,
    surfaceMuted: SevaCareColors.surfaceMuted,
    glassSurface: SevaCareColors.glassSurface,
    glassBorder: SevaCareColors.glassBorder,
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
    sky: SevaCareColors.sky,
    skySoft: SevaCareColors.skySoft,
    skyForeground: SevaCareColors.skyForeground,
    border: SevaCareColors.border,
    overlay: SevaCareColors.overlay,
    shadowColor: SevaCareColors.shadowColor,
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
    skyGradient: SevaCareColors.skyGradient,
    dangerGradient: SevaCareColors.dangerGradient,
    screenGradient: SevaCareColors.screenGradient,
  );

  // ── Light: clinic (teal) ──────────────────────────────────────────────────
  static const AppThemeColors clinic = AppThemeColors(
    brightness: Brightness.light,
    background: SevaCareColors.background,
    surface: SevaCareColors.surface,
    surfaceMuted: SevaCareColors.surfaceMuted,
    glassSurface: SevaCareColors.glassSurface,
    glassBorder: SevaCareColors.glassBorder,
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
    sky: SevaCareColors.sky,
    skySoft: SevaCareColors.skySoft,
    skyForeground: SevaCareColors.skyForeground,
    border: SevaCareColors.border,
    overlay: SevaCareColors.overlay,
    shadowColor: SevaCareColors.shadowColor,
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
    skyGradient: SevaCareColors.skyGradient,
    dangerGradient: SevaCareColors.dangerGradient,
    screenGradient: SevaCareColors.screenGradient,
  );

  // ── Dark ──────────────────────────────────────────────────────────────────
  static const AppThemeColors dark = AppThemeColors(
    brightness: Brightness.dark,
    background: Color(0xFF0F1117),
    surface: Color(0xFF191C24),
    surfaceMuted: Color(0xFF232733),
    glassSurface: Color(0xB8191C24), // rgba(25,28,36,0.72)
    glassBorder: Color(0x99343A4C),  // rgba(52,58,76,0.60)
    text: Color(0xFFF1F0F6),
    textMuted: Color(0xFF9B9AAB),
    textOnPrimary: Color(0xFFFAFAF9),
    primary: Color(0xFF8B80EA),
    primaryStrong: Color(0xFF7C6FE0),
    primarySoft: Color(0xFF262340),
    mint: Color(0xFF52C499),
    mintSoft: Color(0xFF15342A),
    mintForeground: Color(0xFF83E3C1),
    peach: Color(0xFFF0A86B),
    peachSoft: Color(0xFF3A2A1A),
    peachForeground: Color(0xFFF3C99E),
    sky: Color(0xFF5AA6E5),
    skySoft: Color(0xFF16283A),
    skyForeground: Color(0xFFAAD4F3),
    border: Color(0xFF2C3040),
    overlay: Color(0x148B80EA),
    shadowColor: Color(0xFF000000),
    error: Color(0xFFF2685A),
    danger: Color(0xFFF2685A),
    success: Color(0xFF4ECB8E),
    warning: Color(0xFFE5B565),
    errorSurface: Color(0xFF37211E),
    successSurface: Color(0xFF15342A),
    warningSurface: Color(0xFF37301C),
    buttonGradient: [Color(0xFF6F63D6), Color(0xFF8B80EA)],
    heroGradient: [Color(0xFF3F39A8), Color(0xFF6F63D6)],
    mintGradient: [Color(0xFF52C499), Color(0xFF3BAE85)],
    peachGradient: [Color(0xFFF2C072), Color(0xFFE8805A)],
    skyGradient: [Color(0xFF4C9FE0), Color(0xFF2D6FA8)],
    dangerGradient: [Color(0xFFF2685A), Color(0xFFC0432E)],
    screenGradient: [Color(0xFF0F1117), Color(0xFF14121C), Color(0xFF101614)],
  );

  static AppThemeColors forTenant(TenantTheme tenant) {
    return tenant == TenantTheme.clinic ? clinic : premium;
  }

  @override
  AppThemeColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? glassSurface,
    Color? glassBorder,
    Color? text,
    Color? textMuted,
    Color? textOnPrimary,
    Color? primary,
    Color? primaryStrong,
    Color? primarySoft,
    Color? mint,
    Color? mintSoft,
    Color? mintForeground,
    Color? peach,
    Color? peachSoft,
    Color? peachForeground,
    Color? sky,
    Color? skySoft,
    Color? skyForeground,
    Color? border,
    Color? overlay,
    Color? shadowColor,
    Color? error,
    Color? danger,
    Color? success,
    Color? warning,
    Color? errorSurface,
    Color? successSurface,
    Color? warningSurface,
    List<Color>? buttonGradient,
    List<Color>? heroGradient,
    List<Color>? mintGradient,
    List<Color>? peachGradient,
    List<Color>? skyGradient,
    List<Color>? dangerGradient,
    List<Color>? screenGradient,
  }) {
    return AppThemeColors(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      glassSurface: glassSurface ?? this.glassSurface,
      glassBorder: glassBorder ?? this.glassBorder,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textOnPrimary: textOnPrimary ?? this.textOnPrimary,
      primary: primary ?? this.primary,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      primarySoft: primarySoft ?? this.primarySoft,
      mint: mint ?? this.mint,
      mintSoft: mintSoft ?? this.mintSoft,
      mintForeground: mintForeground ?? this.mintForeground,
      peach: peach ?? this.peach,
      peachSoft: peachSoft ?? this.peachSoft,
      peachForeground: peachForeground ?? this.peachForeground,
      sky: sky ?? this.sky,
      skySoft: skySoft ?? this.skySoft,
      skyForeground: skyForeground ?? this.skyForeground,
      border: border ?? this.border,
      overlay: overlay ?? this.overlay,
      shadowColor: shadowColor ?? this.shadowColor,
      error: error ?? this.error,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      errorSurface: errorSurface ?? this.errorSurface,
      successSurface: successSurface ?? this.successSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      buttonGradient: buttonGradient ?? this.buttonGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      mintGradient: mintGradient ?? this.mintGradient,
      peachGradient: peachGradient ?? this.peachGradient,
      skyGradient: skyGradient ?? this.skyGradient,
      dangerGradient: dangerGradient ?? this.dangerGradient,
      screenGradient: screenGradient ?? this.screenGradient,
    );
  }

  static List<Color> _lerpGradient(List<Color> a, List<Color> b, double t) {
    final n = a.length < b.length ? a.length : b.length;
    return [for (int i = 0; i < n; i++) Color.lerp(a[i], b[i], t)!];
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      glassSurface: Color.lerp(glassSurface, other.glassSurface, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnPrimary: Color.lerp(textOnPrimary, other.textOnPrimary, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      primarySoft: Color.lerp(primarySoft, other.primarySoft, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      mintSoft: Color.lerp(mintSoft, other.mintSoft, t)!,
      mintForeground: Color.lerp(mintForeground, other.mintForeground, t)!,
      peach: Color.lerp(peach, other.peach, t)!,
      peachSoft: Color.lerp(peachSoft, other.peachSoft, t)!,
      peachForeground: Color.lerp(peachForeground, other.peachForeground, t)!,
      sky: Color.lerp(sky, other.sky, t)!,
      skySoft: Color.lerp(skySoft, other.skySoft, t)!,
      skyForeground: Color.lerp(skyForeground, other.skyForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      error: Color.lerp(error, other.error, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      errorSurface: Color.lerp(errorSurface, other.errorSurface, t)!,
      successSurface: Color.lerp(successSurface, other.successSurface, t)!,
      warningSurface: Color.lerp(warningSurface, other.warningSurface, t)!,
      buttonGradient: _lerpGradient(buttonGradient, other.buttonGradient, t),
      heroGradient: _lerpGradient(heroGradient, other.heroGradient, t),
      mintGradient: _lerpGradient(mintGradient, other.mintGradient, t),
      peachGradient: _lerpGradient(peachGradient, other.peachGradient, t),
      skyGradient: _lerpGradient(skyGradient, other.skyGradient, t),
      dangerGradient: _lerpGradient(dangerGradient, other.dangerGradient, t),
      screenGradient: _lerpGradient(screenGradient, other.screenGradient, t),
    );
  }
}

/// One ergonomic access point for theme colours. Prefer `context.colors.text`
/// over `SevaCareColors.text` — it resolves to the light or dark value for the
/// active theme automatically. Falls back to the premium light set if the
/// extension is somehow absent (e.g. a bare test `MaterialApp`).
extension AppColorsX on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.premium;
}
