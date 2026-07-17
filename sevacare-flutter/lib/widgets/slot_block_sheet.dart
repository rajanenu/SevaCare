import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/error_utils.dart';
import '../data/models/models.dart';
import '../providers/app_state.dart';
import 'gradient_button.dart';

/// Bottom sheet where a doctor blocks part of a day (next 2 hours, half day,
/// full day, or a custom window). Blocked windows immediately become
/// unavailable in patient and IP-Staff booking.
Future<void> showSlotBlockSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _SlotBlockSheet(),
  );
}

class _SlotBlockSheet extends ConsumerStatefulWidget {
  const _SlotBlockSheet();

  @override
  ConsumerState<_SlotBlockSheet> createState() => _SlotBlockSheetState();
}

class _SlotBlockSheetState extends ConsumerState<_SlotBlockSheet> {
  List<SlotBlockView> _blocks = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  // Custom window state
  DateTime _customDate = DateTime.now();
  TimeOfDay _customStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _customEnd = const TimeOfDay(hour: 11, minute: 0);
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBlocks() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final blocks = await ref.read(repositoryProvider).listSlotBlocks(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _blocks = blocks;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = extractErrorMessage(e, fallback: 'Failed to load blocks.');
          _loading = false;
        });
      }
    }
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _createBlock(String date, String start, String end, String reason) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).createSlotBlock(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            auth.token ?? '',
            date: date,
            startTime: start,
            endTime: end,
            reason: reason,
          );
      _reasonCtrl.clear();
      await _loadBlocks();
    } catch (e) {
      if (mounted) {
        setState(() => _error = extractErrorMessage(e, fallback: 'Could not block slots.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteBlock(SlotBlockView block) async {
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).deleteSlotBlock(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            block.blockPublicId,
            auth.token ?? '',
          );
      await _loadBlocks();
    } catch (e) {
      if (mounted) {
        setState(() => _error = extractErrorMessage(e, fallback: 'Could not remove block.'));
      }
    }
  }

  // ── Quick presets ───────────────────────────────────────────────────────────

  void _blockNextTwoHours() {
    final now = TimeOfDay.now();
    // Snap start to the current 15-min slot; cap end at 21:00
    final startMinutes = (now.hour * 60 + (now.minute ~/ 15) * 15).clamp(9 * 60, 21 * 60 - 15);
    final endMinutes = (startMinutes + 120).clamp(startMinutes + 15, 21 * 60);
    final start = TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);
    final end = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
    _createBlock(_fmtDate(DateTime.now()), _fmtTime(start), _fmtTime(end), 'Blocked for 2 hours');
  }

  void _blockRestOfMorning() {
    final now = TimeOfDay.now();
    final startMinutes = (now.hour * 60 + (now.minute ~/ 15) * 15).clamp(9 * 60, 14 * 60 - 15);
    final start = TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);
    _createBlock(_fmtDate(DateTime.now()), _fmtTime(start), '14:00', 'Morning session off');
  }

  void _blockEvening() {
    _createBlock(_fmtDate(DateTime.now()), '17:00', '21:00', 'Evening session off');
  }

  void _blockFullDay() {
    _createBlock(_fmtDate(DateTime.now()), '09:00', '21:00', 'Unavailable all day');
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _customDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked != null) setState(() => _customDate = picked);
  }

  Future<void> _pickCustomTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _customStart : _customEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _customStart = picked;
        } else {
          _customEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.event_busy_rounded, size: 20, color: context.colors.primary),
                const SizedBox(width: 8),
                Text('Block Appointment Slots',
                    style: AppTextStyles.cardTitle(context.colors.text)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Blocked times instantly show as unavailable to patients and IP-Staff.',
              style: AppTextStyles.label(context.colors.textMuted),
            ),
            const SizedBox(height: 14),

            // ── Quick presets ───────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Next 2 hours',
                  onTap: _saving ? null : _blockNextTwoHours,
                ),
                _PresetChip(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Rest of morning',
                  onTap: _saving ? null : _blockRestOfMorning,
                ),
                _PresetChip(
                  icon: Icons.nights_stay_outlined,
                  label: 'Evening off',
                  onTap: _saving ? null : _blockEvening,
                ),
                _PresetChip(
                  icon: Icons.event_busy_outlined,
                  label: 'Full day',
                  onTap: _saving ? null : _blockFullDay,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Custom window ───────────────────────────────────────────────
            Text('Custom window', style: AppTextStyles.sectionTitle(context.colors.text)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    icon: Icons.calendar_today_outlined,
                    label: _fmtDate(_customDate),
                    onTap: _pickCustomDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule_outlined,
                    label: _fmtTime(_customStart),
                    onTap: () => _pickCustomTime(isStart: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PickerTile(
                    icon: Icons.schedule,
                    label: _fmtTime(_customEnd),
                    onTap: () => _pickCustomTime(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonCtrl,
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: AppTextStyles.label(context.colors.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: context.colors.border),
                ),
              ),
              style: AppTextStyles.bodyText(context.colors.text),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Block this window',
              icon: Icons.block_rounded,
              isLoading: _saving,
              fullWidth: true,
              onPressed: _saving
                  ? null
                  : () => _createBlock(
                        _fmtDate(_customDate),
                        _fmtTime(_customStart),
                        _fmtTime(_customEnd),
                        _reasonCtrl.text.trim(),
                      ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.errorSurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: AppTextStyles.label(context.colors.danger)),
              ),
            ],

            const SizedBox(height: 18),

            // ── Existing blocks ─────────────────────────────────────────────
            Text('Upcoming blocks', style: AppTextStyles.sectionTitle(context.colors.text)),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_blocks.isEmpty)
              Text('No blocked windows.',
                  style: AppTextStyles.bodyText(context.colors.textMuted))
            else
              ..._blocks.map(
                (b) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_busy_outlined,
                          size: 16, color: context.colors.warning),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${b.date}  ·  ${b.startTime} – ${b.endTime}',
                                style: AppTextStyles.body(
                                  size: 13,
                                  weight: FontWeight.w600,
                                  color: context.colors.text,
                                )),
                            if (b.reason.isNotEmpty)
                              Text(b.reason,
                                  style: AppTextStyles.label(context.colors.textMuted)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: context.colors.danger),
                        tooltip: 'Remove block',
                        onPressed: () => _deleteBlock(b),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _PresetChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: context.colors.primarySoft,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.colors.primary),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.label(context.colors.primary)),
            ],
          ),
        ),
      );
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: context.colors.textMuted),
              const SizedBox(width: 6),
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
