import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

enum MetricVariant { primary, mint, peach, danger }

extension _MetricVariantX on MetricVariant {
  List<Color> get gradient => switch (this) {
    MetricVariant.primary => SevaCareColors.buttonGradient,
    MetricVariant.mint => SevaCareColors.mintGradient,
    MetricVariant.peach => SevaCareColors.peachGradient,
    MetricVariant.danger => SevaCareColors.dangerGradient,
  };

  Color get valueColor => switch (this) {
    MetricVariant.primary => SevaCareColors.primary,
    MetricVariant.mint => SevaCareColors.mint,
    MetricVariant.peach => SevaCareColors.peach,
    MetricVariant.danger => SevaCareColors.danger,
  };
}

class MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final MetricVariant variant;
  final String? trend;
  final VoidCallback? onTap;

  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    this.variant = MetricVariant.primary,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: SevaCareColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4px gradient accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: variant.gradient,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: AppTextStyles.metricLabel(SevaCareColors.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: AppTextStyles.metricValue(variant.valueColor),
                      ),
                      if (trend != null && trend!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          trend!,
                          style: AppTextStyles.body(
                            size: 11,
                            color: SevaCareColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: tile);
    }
    return tile;
  }
}

// Row of metric tiles that wraps
class MetricRow extends StatelessWidget {
  final List<MetricTile> tiles;
  const MetricRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: tiles
          .asMap()
          .entries
          .map((e) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: e.key == 0 ? 0 : 8),
                  child: e.value,
                ),
              ))
          .toList(),
    );
  }
}
