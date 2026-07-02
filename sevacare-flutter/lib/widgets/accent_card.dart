import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'metric_tile.dart';

class AccentCard extends StatelessWidget {
  final Widget child;
  final MetricVariant variant;
  final VoidCallback? onTap;

  const AccentCard({
    super.key,
    required this.child,
    this.variant = MetricVariant.primary,
    this.onTap,
  });

  List<Color> get _gradient => switch (variant) {
    MetricVariant.primary => SevaCareColors.buttonGradient,
    MetricVariant.mint => SevaCareColors.mintGradient,
    MetricVariant.peach => SevaCareColors.peachGradient,
    MetricVariant.danger => SevaCareColors.dangerGradient,
  };

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4px gradient bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _gradient,
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: SevaCareColors.surface,
                  border: Border(
                    top: BorderSide(color: SevaCareColors.border),
                    right: BorderSide(color: SevaCareColors.border),
                    bottom: BorderSide(color: SevaCareColors.border),
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(AppTheme.radius),
                    bottomRight: Radius.circular(AppTheme.radius),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}
