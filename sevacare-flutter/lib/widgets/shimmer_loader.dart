import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer placeholder that matches a card layout.
class ShimmerCard extends StatelessWidget {
  final double height;
  final int lines;
  const ShimmerCard({super.key, this.height = 90, this.lines = 3});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF4A5568) : const Color(0xFFF7FAFC);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(height: 14, width: double.infinity, decoration: _pill()),
            for (int i = 0; i < lines - 1; i++)
              Container(
                height: 10,
                width: i.isEven ? double.infinity : 180,
                decoration: _pill(),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _pill() => BoxDecoration(
        color: Colors.white,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0);
    final highlight = isDark ? const Color(0xFF4A5568) : const Color(0xFFF7FAFC);

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Row(
        children: [
          Expanded(child: _tile()),
          const SizedBox(width: 10),
          Expanded(child: _tile()),
        ],
      ),
    );
  }

  Widget _tile() => Container(
        height: 76,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      );
}
