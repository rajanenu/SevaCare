import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  // Display font — Sora (headings, values)
  static TextStyle display({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // Body font — Inter (labels, body, muted text)
  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // Convenience shortcuts
  static TextStyle heroTitle(Color color) => display(size: 26, weight: FontWeight.w800, color: color, height: 1.25, letterSpacing: 0.2);
  static TextStyle pageTitle(Color color) => display(size: 22, weight: FontWeight.w700, color: color);
  static TextStyle sectionTitle(Color color) => display(size: 16, weight: FontWeight.w600, color: color);
  static TextStyle cardTitle(Color color) => body(size: 14, weight: FontWeight.w600, color: color);
  static TextStyle label(Color color) => body(size: 12, weight: FontWeight.w500, color: color, letterSpacing: 0.3);
  static TextStyle labelCaps(Color color) => body(size: 11, weight: FontWeight.w600, color: color, letterSpacing: 0.6);
  static TextStyle bodyText(Color color) => body(size: 13, weight: FontWeight.w400, color: color, height: 1.5);
  static TextStyle metricValue(Color color) => display(size: 24, weight: FontWeight.w700, color: color);
  static TextStyle metricLabel(Color color) => body(size: 11, weight: FontWeight.w600, color: color, letterSpacing: 0.6);
  static TextStyle buttonLabel(Color color) => body(size: 15, weight: FontWeight.w600, color: color, letterSpacing: 0.2);
  static TextStyle chipLabel(Color color) => body(size: 12, weight: FontWeight.w600, color: color);
  static TextStyle inputText(Color color) => body(size: 14, weight: FontWeight.w400, color: color);
  static TextStyle inputHint(Color color) => body(size: 14, weight: FontWeight.w400, color: color);
  static TextStyle badgeText(Color color) => body(size: 10, weight: FontWeight.w700, color: color, letterSpacing: 0.4);
}
