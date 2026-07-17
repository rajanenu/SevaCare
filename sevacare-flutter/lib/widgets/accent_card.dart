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

  List<Color> _gradient(BuildContext context) => switch (variant) {
    MetricVariant.primary => context.colors.buttonGradient,
    MetricVariant.mint => context.colors.mintGradient,
    MetricVariant.peach => context.colors.peachGradient,
    MetricVariant.danger => context.colors.dangerGradient,
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
                  colors: _gradient(context),
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: context.colors.border),
                    right: BorderSide(color: context.colors.border),
                    bottom: BorderSide(color: context.colors.border),
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
