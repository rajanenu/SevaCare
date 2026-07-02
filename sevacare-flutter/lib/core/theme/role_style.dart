import 'package:flutter/material.dart';
import '../../data/models/models.dart';
import 'app_colors.dart';

/// Visual identity (icon + accent colors) per persona — kept in one place so
/// the login role-picker, the top bar, and any future role UI stay in sync.
extension UserRoleStyle on UserRole {
  IconData get icon => switch (this) {
    UserRole.patient => Icons.favorite_rounded,
    UserRole.doctor => Icons.medical_services_rounded,
    UserRole.admin => Icons.admin_panel_settings_rounded,
    UserRole.staff => Icons.badge_rounded,
    UserRole.platformAdmin => Icons.settings_rounded,
  };

  Color get bgColor => switch (this) {
    UserRole.patient => SevaCareColors.primarySoft,
    UserRole.doctor => SevaCareColors.mintSoft,
    UserRole.admin => SevaCareColors.peachSoft,
    UserRole.staff => SevaCareColors.skySoft,
    UserRole.platformAdmin => SevaCareColors.surfaceMuted,
  };

  Color get fgColor => switch (this) {
    UserRole.patient => SevaCareColors.primary,
    UserRole.doctor => SevaCareColors.mintForeground,
    UserRole.admin => SevaCareColors.peachForeground,
    UserRole.staff => SevaCareColors.skyForeground,
    UserRole.platformAdmin => SevaCareColors.textMuted,
  };
}
