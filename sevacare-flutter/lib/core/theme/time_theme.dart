import 'package:flutter/material.dart';

/// Time-of-day visual theme: hero banners pick up a subtle nature-inspired
/// tint that follows the clock (sunrise warmth, daylight sky, dusk amber,
/// night indigo) so the app feels calm and alive without changing any layout.
enum DayPhase { morning, afternoon, evening, night }

DayPhase currentDayPhase([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h >= 5 && h < 12) return DayPhase.morning;
  if (h >= 12 && h < 17) return DayPhase.afternoon;
  if (h >= 17 && h < 20) return DayPhase.evening;
  return DayPhase.night;
}

extension DayPhaseTheme on DayPhase {
  String get greeting => switch (this) {
        DayPhase.morning => 'Good morning',
        DayPhase.afternoon => 'Good afternoon',
        DayPhase.evening => 'Good evening',
        DayPhase.night => 'Good night',
      };

  IconData get icon => switch (this) {
        DayPhase.morning => Icons.wb_sunny_rounded,
        DayPhase.afternoon => Icons.light_mode_rounded,
        DayPhase.evening => Icons.wb_twilight_rounded,
        DayPhase.night => Icons.nights_stay_rounded,
      };

  /// Soft translucent tint layered on top of role hero gradients.
  /// Alphas stay low so role colors and text contrast are preserved.
  List<Color> get overlayTint => switch (this) {
        // Fresh green-gold sunrise
        DayPhase.morning => const [Color(0x33FFE29A), Color(0x2270C980)],
        // Clear daylight blue
        DayPhase.afternoon => const [Color(0x2287CEFA), Color(0x11FFFFFF)],
        // Warm dusk amber-rose
        DayPhase.evening => const [Color(0x33FFB347), Color(0x22B06AB3)],
        // Calm deep night
        DayPhase.night => const [Color(0x44101A3C), Color(0x22030A1C)],
      };
}

/// Drop-in overlay for hero banners: `Positioned.fill(child: TimeTintOverlay())`.
class TimeTintOverlay extends StatelessWidget {
  const TimeTintOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final phase = currentDayPhase();
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: phase.overlayTint,
          ),
        ),
      ),
    );
  }
}
