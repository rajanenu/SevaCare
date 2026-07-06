import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Compact read-only star row for showing a doctor's average rating, e.g. on
/// Explore Doctors and the booking screen. Renders nothing if there are no
/// reviews yet, so doctors without ratings look unchanged.
class RatingStars extends StatelessWidget {
  final double? averageRating;
  final int reviewCount;
  final double size;

  const RatingStars({
    super.key,
    required this.averageRating,
    required this.reviewCount,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (averageRating == null || reviewCount <= 0) {
      return const SizedBox.shrink();
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: size, color: const Color(0xFFF5B300)),
        const SizedBox(width: 3),
        Text(
          averageRating!.toStringAsFixed(1),
          style: AppTextStyles.label(SevaCareColors.text).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 3),
        Text(
          '($reviewCount)',
          style: AppTextStyles.label(SevaCareColors.textMuted),
        ),
      ],
    );
  }
}

/// Interactive 5-star picker used in the "Rate your visit" bottom sheet.
class RatingStarsPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  const RatingStarsPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return IconButton(
          onPressed: () => onChanged(starValue),
          icon: Icon(
            starValue <= value ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFF5B300),
            size: size,
          ),
        );
      }),
    );
  }
}
