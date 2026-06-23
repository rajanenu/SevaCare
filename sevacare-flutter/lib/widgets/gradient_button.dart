import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

enum ButtonVariant { primary, secondary, danger, mint, ghost }

class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final bool compact;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    Widget child = isLoading
        ? SizedBox(
            width: compact ? 16 : 20,
            height: compact ? 16 : 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_foregroundColor()),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 14 : 18, color: _foregroundColor()),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: compact
                    ? AppTextStyles.label(_foregroundColor())
                    : AppTextStyles.buttonLabel(_foregroundColor()),
              ),
            ],
          );

    if (fullWidth) {
      child = Center(child: child);
    }

    final button = Container(
      constraints: fullWidth
          ? const BoxConstraints(minHeight: 50)
          : compact
              ? const BoxConstraints(minHeight: 32)
              : const BoxConstraints(minHeight: 46),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
      decoration: BoxDecoration(
        gradient: _gradientOrNull(isDisabled),
        color: _gradientOrNull(isDisabled) == null ? _solidColor() : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: variant == ButtonVariant.secondary
            ? Border.all(color: SevaCareColors.primary, width: 1.5)
            : variant == ButtonVariant.ghost
                ? Border.all(color: SevaCareColors.border, width: 1.5)
                : null,
        boxShadow: variant == ButtonVariant.primary && !isDisabled && !compact
            ? [
                BoxShadow(
                  color: SevaCareColors.primary.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : variant == ButtonVariant.danger && !isDisabled && !compact
                ? [
                    BoxShadow(
                      color: SevaCareColors.danger.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
      ),
      child: child,
    );

    if (isDisabled) {
      return Opacity(opacity: 0.6, child: button);
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed!();
      },
      child: button,
    );
  }

  LinearGradient? _gradientOrNull(bool disabled) {
    if (disabled) return null;
    return switch (variant) {
      ButtonVariant.primary => const LinearGradient(
          colors: SevaCareColors.buttonGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ButtonVariant.danger => const LinearGradient(
          colors: SevaCareColors.dangerGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ButtonVariant.mint => const LinearGradient(
          colors: SevaCareColors.mintGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      _ => null,
    };
  }

  Color _solidColor() => switch (variant) {
    ButtonVariant.secondary => Colors.transparent,
    ButtonVariant.ghost => Colors.transparent,
    ButtonVariant.primary => SevaCareColors.primary,
    ButtonVariant.danger => SevaCareColors.danger,
    ButtonVariant.mint => SevaCareColors.mint,
  };

  Color _foregroundColor() => switch (variant) {
    ButtonVariant.secondary => SevaCareColors.primary,
    ButtonVariant.ghost => SevaCareColors.textMuted,
    _ => SevaCareColors.textOnPrimary,
  };
}

// Convenience wrappers
class PrimaryButton extends GradientButton {
  const PrimaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.isLoading,
    super.icon,
    super.fullWidth,
    super.compact,
  }) : super(variant: ButtonVariant.primary);
}

class SecondaryButton extends GradientButton {
  const SecondaryButton({
    super.key,
    required super.label,
    super.onPressed,
    super.isLoading,
    super.icon,
    super.fullWidth,
    super.compact,
  }) : super(variant: ButtonVariant.secondary);
}

class DangerButton extends GradientButton {
  const DangerButton({
    super.key,
    required super.label,
    super.onPressed,
    super.isLoading,
    super.icon,
    super.fullWidth,
    super.compact,
  }) : super(variant: ButtonVariant.danger);
}

// Back button — glass pill
class BackBtn extends StatelessWidget {
  final VoidCallback? onPressed;
  const BackBtn({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: SevaCareColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: SevaCareColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_left, size: 18, color: SevaCareColors.text),
            Text('Back', style: AppTextStyles.label(SevaCareColors.text)),
          ],
        ),
      ),
    );
  }
}

/// Small icon-only action button for card action rows.
class IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? iconColor;
  final Color? bgColor;
  final String tooltip;

  const IconBtn({
    super.key,
    required this.icon,
    this.onPressed,
    this.iconColor,
    this.bgColor,
    this.tooltip = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: bgColor ?? SevaCareColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SevaCareColors.border, width: 1),
            ),
            child: Icon(icon, size: 16, color: iconColor ?? SevaCareColors.textMuted),
          ),
        ),
      ),
    );
  }
}
