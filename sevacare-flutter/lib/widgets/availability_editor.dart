import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

/// One doctor-controlled working-hours window scoped to a date range: an
/// optional from/to date (null = unbounded / ongoing), Saturday/Sunday
/// inclusion flags, and a start/end time. Mirrors the backend's
/// DoctorWorkingHoursRule (doctor_availability table) 1:1.
///
/// When several rules cover the same date, the backend uses the NARROWEST
/// date range — so a single-day rule overrides the general schedule that day.
class AvailabilityRule {
  String dayScope; // legacy passthrough; new rules always use EVERYDAY
  DateTime? fromDate;
  DateTime? toDate;
  bool includeSaturday;
  bool includeSunday;
  TimeOfDay start;
  TimeOfDay end;

  AvailabilityRule({
    this.dayScope = 'EVERYDAY',
    this.fromDate,
    this.toDate,
    this.includeSaturday = true,
    this.includeSunday = true,
    required this.start,
    required this.end,
  });

  /// Morning/Evening is purely a display label derived from the start time —
  /// the backend stores whatever we send but nothing depends on its wording.
  String get sessionLabel => start.hour < 12 ? 'Morning' : 'Evening';

  int get _startMinutes => start.hour * 60 + start.minute;
  int get _endMinutes => end.hour * 60 + end.minute;
  bool get isAtLeastTwoHours => _endMinutes - _startMinutes >= 120;

  Map<String, dynamic> toJson() => {
        'dayScope': dayScope,
        'sessionLabel': sessionLabel,
        'startTime': _fmt(start),
        'endTime': _fmt(end),
        'fromDate': fromDate == null ? null : _fmtDate(fromDate!),
        'toDate': toDate == null ? null : _fmtDate(toDate!),
        'includeSaturday': includeSaturday,
        'includeSunday': includeSunday,
      };

  static AvailabilityRule fromJson(Map<String, dynamic> json) {
    return AvailabilityRule(
      dayScope: json['dayScope'] as String? ?? 'EVERYDAY',
      fromDate: _parseDate(json['fromDate'] as String?),
      toDate: _parseDate(json['toDate'] as String?),
      includeSaturday: json['includeSaturday'] as bool? ?? true,
      includeSunday: json['includeSunday'] as bool? ?? true,
      start: _parse(json['startTime'] as String? ?? '09:00'),
      end: _parse(json['endTime'] as String? ?? '14:00'),
    );
  }

  static List<AvailabilityRule> defaultRules() => [
        AvailabilityRule(start: const TimeOfDay(hour: 9, minute: 0), end: const TimeOfDay(hour: 14, minute: 0)),
        AvailabilityRule(start: const TimeOfDay(hour: 17, minute: 0), end: const TimeOfDay(hour: 21, minute: 0)),
      ];

  static String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static TimeOfDay _parse(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
  }
}

/// A group of time windows sharing one date range + weekend flags — what the
/// doctor sees as a single "schedule" card in the editor.
class _Schedule {
  DateTime? fromDate;
  DateTime? toDate;
  bool includeSaturday;
  bool includeSunday;
  List<_Window> windows;

  _Schedule({
    this.fromDate,
    this.toDate,
    this.includeSaturday = true,
    this.includeSunday = true,
    required this.windows,
  });

  bool get isSingleDay =>
      fromDate != null && toDate != null && _sameDay(fromDate!, toDate!);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _rangeKey() =>
      '${fromDate?.toIso8601String() ?? ''}|${toDate?.toIso8601String() ?? ''}|$includeSaturday|$includeSunday';
}

class _Window {
  TimeOfDay start;
  TimeOfDay end;
  _Window(this.start, this.end);

  bool get isAtLeastTwoHours =>
      (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute) >= 120;
}

/// Date-range based working-hours editor — used in both the doctor's own
/// Profile screen and the admin's Add/Edit Doctor form.
///
/// Each card is one schedule: a from/to date range (to-date optional =
/// ongoing), whether Saturdays/Sundays are included, and one or more time
/// windows. To change hours for just one day (e.g. next Monday), the doctor
/// adds a schedule where from-date == to-date — the backend gives the
/// narrowest range priority on that date.
class AvailabilityEditor extends StatefulWidget {
  final List<AvailabilityRule> initialRules;
  final ValueChanged<List<AvailabilityRule>> onChanged;

  const AvailabilityEditor({super.key, required this.initialRules, required this.onChanged});

  /// Null when the rules are valid, else a user-facing message.
  static String? validate(List<AvailabilityRule> rules) {
    if (rules.isEmpty) return 'Add at least one availability window.';
    for (final r in rules) {
      if (!r.isAtLeastTwoHours) {
        return 'Each availability window must be at least 2 hours long.';
      }
      if (r.fromDate != null && r.toDate != null && r.toDate!.isBefore(r.fromDate!)) {
        return 'A schedule\'s "to" date cannot be before its "from" date.';
      }
    }
    return null;
  }

  @override
  State<AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<AvailabilityEditor> {
  late List<_Schedule> _schedules;

  @override
  void initState() {
    super.initState();
    final rules = widget.initialRules.isEmpty ? AvailabilityRule.defaultRules() : widget.initialRules;
    _schedules = _group(rules);
  }

  /// Groups flat backend rules into schedule cards by (range, weekend flags).
  List<_Schedule> _group(List<AvailabilityRule> rules) {
    final map = <String, _Schedule>{};
    final order = <String>[];
    for (final r in rules) {
      final s = _Schedule(
        fromDate: r.fromDate,
        toDate: r.toDate,
        includeSaturday: r.includeSaturday,
        includeSunday: r.includeSunday,
        windows: [],
      );
      final key = s._rangeKey();
      final existing = map[key];
      if (existing == null) {
        map[key] = s;
        order.add(key);
        s.windows.add(_Window(r.start, r.end));
      } else {
        existing.windows.add(_Window(r.start, r.end));
      }
    }
    return [for (final k in order) map[k]!];
  }

  /// Flattens schedule cards back into one rule per time window.
  void _notify() {
    final rules = <AvailabilityRule>[];
    for (final s in _schedules) {
      for (final w in s.windows) {
        rules.add(AvailabilityRule(
          fromDate: s.fromDate,
          toDate: s.toDate,
          includeSaturday: s.includeSaturday,
          includeSunday: s.includeSunday,
          start: w.start,
          end: w.end,
        ));
      }
    }
    widget.onChanged(rules);
  }

  void _addSchedule() {
    final today = DateTime.now();
    setState(() {
      _schedules.add(_Schedule(
        fromDate: DateTime(today.year, today.month, today.day),
        toDate: DateTime(today.year, today.month, today.day),
        windows: [_Window(const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 14, minute: 0))],
      ));
    });
    _notify();
  }

  void _removeSchedule(int index) {
    setState(() => _schedules.removeAt(index));
    _notify();
  }

  Future<void> _pickDate(_Schedule s, {required bool isFrom}) async {
    final today = DateTime.now();
    final initial = (isFrom ? s.fromDate : s.toDate) ?? s.fromDate ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 730)),
      helpText: isFrom ? 'Available from' : 'Available until',
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        s.fromDate = picked;
        if (s.toDate != null && s.toDate!.isBefore(picked)) s.toDate = picked;
      } else {
        s.toDate = picked;
        if (s.fromDate != null && s.fromDate!.isAfter(picked)) s.fromDate = picked;
      }
    });
    _notify();
  }

  Future<void> _pickTime(_Window w, {required bool isStart}) async {
    final picked = await showTimePicker(context: context, initialTime: isStart ? w.start : w.end);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        w.start = picked;
      } else {
        w.end = picked;
      }
    });
    _notify();
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _fmtTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _scheduleTitle(_Schedule s) {
    if (s.fromDate == null && s.toDate == null) return 'Regular schedule';
    if (s.isSingleDay) return 'Only ${_fmtDate(s.fromDate!)}';
    final from = s.fromDate == null ? 'Any date' : _fmtDate(s.fromDate!);
    final to = s.toDate == null ? 'ongoing' : _fmtDate(s.toDate!);
    return '$from → $to';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._schedules.asMap().entries.map((e) => _scheduleCard(e.key, e.value)),
        TextButton.icon(
          onPressed: _addSchedule,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add schedule for specific dates'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Tip: to change your hours for a single day, add a schedule with the '
            'same from & to date — it overrides your regular schedule that day.',
            style: AppTextStyles.label(context.colors.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _scheduleCard(int index, _Schedule s) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: readable summary + remove ──
          Row(
            children: [
              Icon(
                s.fromDate == null && s.toDate == null
                    ? Icons.event_repeat_rounded
                    : (s.isSingleDay ? Icons.today_rounded : Icons.date_range_rounded),
                size: 16,
                color: context.colors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _scheduleTitle(s),
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label(context.colors.text).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (_schedules.length > 1)
                InkWell(
                  onTap: () => _removeSchedule(index),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline_rounded, size: 18, color: context.colors.textMuted),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Date range ──
          Row(
            children: [
              Expanded(
                child: _PickTile(
                  icon: Icons.calendar_today_outlined,
                  label: s.fromDate == null ? 'From: any date' : _fmtDate(s.fromDate!),
                  onTap: () => _pickDate(s, isFrom: true),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, size: 14, color: context.colors.textMuted),
              ),
              Expanded(
                child: _PickTile(
                  icon: Icons.event_outlined,
                  label: s.toDate == null ? 'No end date' : _fmtDate(s.toDate!),
                  onTap: () => _pickDate(s, isFrom: false),
                ),
              ),
            ],
          ),
          if (s.toDate != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  setState(() => s.toDate = null);
                  _notify();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text('Remove end date (keep ongoing)',
                      style: AppTextStyles.label(context.colors.primary)),
                ),
              ),
            ),
          ],
          // ── Weekend inclusion (irrelevant for a single-day schedule) ──
          if (!s.isSingleDay) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Include:', style: AppTextStyles.label(context.colors.textMuted)),
                const SizedBox(width: 8),
                _WeekendChip(
                  label: 'Saturdays',
                  selected: s.includeSaturday,
                  onChanged: (v) {
                    setState(() => s.includeSaturday = v);
                    _notify();
                  },
                ),
                const SizedBox(width: 8),
                _WeekendChip(
                  label: 'Sundays',
                  selected: s.includeSunday,
                  onChanged: (v) {
                    setState(() => s.includeSunday = v);
                    _notify();
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // ── Time windows ──
          ...s.windows.asMap().entries.map((entry) {
            final w = entry.value;
            final tooShort = !w.isAtLeastTwoHours;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        w.start.hour < 12 ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
                        size: 14,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _PickTile(
                          icon: Icons.schedule_outlined,
                          label: _fmtTime(w.start),
                          onTap: () => _pickTime(w, isStart: true),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward, size: 12, color: context.colors.textMuted),
                      ),
                      Expanded(
                        child: _PickTile(
                          icon: Icons.schedule_outlined,
                          label: _fmtTime(w.end),
                          onTap: () => _pickTime(w, isStart: false),
                        ),
                      ),
                      if (s.windows.length > 1)
                        InkWell(
                          onTap: () {
                            setState(() => s.windows.remove(w));
                            _notify();
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 16, color: context.colors.textMuted),
                          ),
                        ),
                    ],
                  ),
                  if (tooShort)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 20),
                      child: Text('Must be at least 2 hours', style: AppTextStyles.label(context.colors.danger)),
                    ),
                ],
              ),
            );
          }),
          InkWell(
            onTap: () {
              setState(() => s.windows.add(
                  _Window(const TimeOfDay(hour: 17, minute: 0), const TimeOfDay(hour: 21, minute: 0))));
              _notify();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: context.colors.primary),
                  const SizedBox(width: 4),
                  Text('Add time window', style: AppTextStyles.label(context.colors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekendChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;
  const _WeekendChip({required this.label, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label,
          style: AppTextStyles.label(selected ? context.colors.primary : context.colors.textMuted)),
      selected: selected,
      onSelected: onChanged,
      selectedColor: context.colors.primarySoft,
      backgroundColor: context.colors.surface,
      checkmarkColor: context.colors.primary,
      side: BorderSide(
          color: selected ? context.colors.primary.withValues(alpha: 0.35) : context.colors.border),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _PickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: context.colors.textMuted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label(context.colors.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
