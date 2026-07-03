import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static final _displayFormat = DateFormat('d MMM yyyy');
  static final _apiFormat = DateFormat('yyyy-MM-dd');
  static final _slotFormat = DateFormat('h:mm a');
  static final _displayDateTime = DateFormat('d MMM yyyy, h:mm a');

  static String formatDisplay(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return _displayFormat.format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  static String formatDateTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return _displayDateTime.format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  static String toApiDate(DateTime dt) => _apiFormat.format(dt);

  static String todayApi() => toApiDate(DateTime.now());

  static String offsetDay(int offset) => toApiDate(DateTime.now().add(Duration(days: offset)));

  static String dayLabel(int offset) {
    if (offset == -1) return 'Yesterday';
    if (offset == 0) return 'Today';
    if (offset == 1) return 'Tomorrow';
    return formatDisplay(offsetDay(offset));
  }

  static String timelineLabel(String apiDate) {
    final today = todayApi();
    final yesterday = offsetDay(-1);
    final tomorrow = offsetDay(1);
    if (apiDate == today) return 'Today';
    if (apiDate == yesterday) return 'Yesterday';
    if (apiDate == tomorrow) return 'Tomorrow';
    return formatDisplay(apiDate);
  }

  static String formatSlot(String? slot) {
    if (slot == null || slot.isEmpty) return '-';
    try {
      final dt = DateTime.parse(slot).toLocal();
      return _slotFormat.format(dt);
    } catch (_) {
      return slot;
    }
  }

  /// Display status for an appointment: a stale "upcoming" whose slot is more
  /// than 24 hours in the past is treated as completed, so old appointments
  /// never show under Upcoming.
  static String effectiveApptStatus(String status, String slot) {
    final s = status.toLowerCase();
    if (s == 'completed' || s == 'cancelled' || s == 'canceled') return status;
    try {
      final dt = DateTime.parse(slot.replaceAll(' ', 'T')).toLocal();
      if (DateTime.now().difference(dt) > const Duration(hours: 24)) {
        return 'completed';
      }
    } catch (_) {}
    return status;
  }
}
