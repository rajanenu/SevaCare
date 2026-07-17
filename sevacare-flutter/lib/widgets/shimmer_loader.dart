import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_colors.dart';

/// Shimmer base/highlight derived from the active theme, so skeletons look
/// right in both light and dark. Highlight is a touch lighter than base.
({Color base, Color highlight}) _shimmerColors(BuildContext context) {
  final c = context.colors;
  if (c.isDark) {
    return (base: c.surfaceMuted, highlight: c.border);
  }
  return (base: c.surfaceMuted, highlight: c.surface);
}

/// Shimmer placeholder that matches a card layout.
class ShimmerCard extends StatelessWidget {
  final double height;
  final int lines;
  const ShimmerCard({super.key, this.height = 90, this.lines = 3});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _shimmerColors(context);

    return Shimmer.fromColors(
      baseColor: s.base,
      highlightColor: s.highlight,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(height: 14, width: double.infinity, decoration: _pill(c.surface)),
            for (int i = 0; i < lines - 1; i++)
              Container(
                height: 10,
                width: i.isEven ? double.infinity : 180,
                decoration: _pill(c.surface),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _pill(Color color) => BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      );
}

/// Full-page shimmer: renders [count] stacked ShimmerCards.
class ShimmerList extends StatelessWidget {
  final int count;
  final double cardHeight;
  const ShimmerList({super.key, this.count = 3, this.cardHeight = 90});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < count; i++) ...[
          ShimmerCard(height: cardHeight),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Two-tile metric row shimmer (for dashboard overview loading).
class ShimmerMetricRow extends StatelessWidget {
  const ShimmerMetricRow({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = _shimmerColors(context);

    return Shimmer.fromColors(
      baseColor: s.base,
      highlightColor: s.highlight,
      child: Row(
        children: [
          Expanded(child: _tile(c.surface)),
          const SizedBox(width: 10),
          Expanded(child: _tile(c.surface)),
        ],
      ),
    );
  }

  Widget _tile(Color color) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
