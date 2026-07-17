import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

enum MetricVariant { primary, mint, peach, danger }

extension _MetricVariantX on MetricVariant {
  List<Color> gradient(BuildContext context) => switch (this) {
    MetricVariant.primary => context.colors.buttonGradient,
    MetricVariant.mint    => context.colors.mintGradient,
    MetricVariant.peach   => context.colors.peachGradient,
    MetricVariant.danger  => context.colors.dangerGradient,
  };

  Color valueColor(BuildContext context) => switch (this) {
    MetricVariant.primary => context.colors.primary,
    MetricVariant.mint    => context.colors.mint,
    MetricVariant.peach   => context.colors.peach,
    MetricVariant.danger  => context.colors.danger,
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: context.colors.border, width: 1),
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
        // Row with CrossAxisAlignment.stretch so the accent bar fills full tile height.
        // MetricRow wraps all tiles in IntrinsicHeight, making every tile in a row equal height.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 4 px gradient accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: variant.gradient(context),
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTextStyles.metricLabel(context.colors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    _AnimatedMetricValue(
                      value: value,
                      style: AppTextStyles.metricValue(variant.valueColor(context)),
                    ),
                    if (trend != null && trend!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        trend!,
                        style: AppTextStyles.body(
                          size: 11,
                          color: context.colors.textMuted,
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
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: tile);
    }
    return tile;
  }
}

/// Renders a metric value with a brief count-up when the number changes.
///
/// It only animates the integer portion of a "mostly numeric" value (an
/// optional prefix like ₹, digits with optional thousands commas, an optional
/// non-decimal suffix like %). Once the animation settles it renders the
/// *exact* original [value] string, so a resting tile is pixel-identical to
/// the plain Text it replaced — anything it can't parse falls straight through
/// to plain Text. No functional behaviour changes; this is purely cosmetic.
class _AnimatedMetricValue extends StatelessWidget {
  final String value;
  final TextStyle style;

  const _AnimatedMetricValue({required this.value, required this.style});

  static final _numeric = RegExp(r'^(\D*?)([\d,]+)(\D*)$');

  @override
  Widget build(BuildContext context) {
    final match = _numeric.firstMatch(value);
    if (match == null) {
      return Text(value, style: style);
    }
    final prefix = match.group(1) ?? '';
    final suffix = match.group(3) ?? '';
    final target = int.tryParse(match.group(2)!.replaceAll(',', ''));
    // Skip the animation for zero (nothing to count) or absurdly large values.
    if (target == null || target <= 0 || target > 100000000) {
      return Text(value, style: style);
    }
    final hadCommas = match.group(2)!.contains(',');

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final current = v.round();
        // At rest, show the caller's exact string (Indian grouping, etc.).
        if (current >= target) return Text(value, style: style);
        final body = hadCommas ? _group(current) : '$current';
        return Text('$prefix$body$suffix', style: style);
      },
    );
  }

  static String _group(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

// Wraps tiles in IntrinsicHeight so every tile in the row is the same height,
// regardless of how long the label text is.
class MetricRow extends StatelessWidget {
  final List<MetricTile> tiles;
  const MetricRow({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
      ),
    );
  }
}
