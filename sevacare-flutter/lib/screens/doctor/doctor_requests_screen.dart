import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auto_refresh.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class DoctorRequestsScreen extends ConsumerStatefulWidget {
  const DoctorRequestsScreen({super.key});

  @override
  ConsumerState<DoctorRequestsScreen> createState() => _DoctorRequestsScreenState();
}

class _DoctorRequestsScreenState extends ConsumerState<DoctorRequestsScreen>
    with AutoRefreshMixin {
  int _tab = 0; // 0=Leave, 1=Message Admin, 2=History

  final _messageCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _fromDateCtrl = TextEditingController();
  final _toDateCtrl = TextEditingController();
  String _leaveType = 'SICK';
  bool _hourlyLeave = false; // false = full day(s), true = time-range leave
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _submitting = false;
  String? _successMsg;

  LeaveRequestCollection? _history;
  bool _loadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    startAutoRefresh(() => _loadHistory(silent: true));
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _reasonCtrl.dispose();
    _fromDateCtrl.dispose();
    _toDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent) setState(() { _loadingHistory = true; _historyError = null; });
    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(repositoryProvider).getDoctorLeaveRequests(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
      );
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted && !silent) setState(() => _historyError = extractErrorMessage(e, fallback: 'Failed to load history.'));
    } finally {
      if (mounted && !silent) setState(() => _loadingHistory = false);
    }
  }

  // The header and tab bar live in a fixed (non-scrolling) frame, so
  // switching tabs only swaps the content region below — nothing else moves.
  void _switchTab(int i) {
    setState(() { _tab = i; _successMsg = null; });
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
    );
    if (picked != null && mounted) {
      ctrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0))
          : (_endTime ?? const TimeOfDay(hour: 12, minute: 0)),
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submitLeave() async {
    if (_fromDateCtrl.text.isEmpty || _toDateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select from and to dates.')),
      );
      return;
    }
    if (_hourlyLeave) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end time for hourly leave.')),
        );
        return;
      }
      final startMins = _startTime!.hour * 60 + _startTime!.minute;
      final endMins = _endTime!.hour * 60 + _endTime!.minute;
      if (endMins <= startMins) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time.')),
        );
        return;
      }
    }
    setState(() { _submitting = true; _successMsg = null; });
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).createLeaveRequest(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
        '', // adminPublicId — backend resolves from tenant
        {
          'leaveType': _leaveType,
          'fromDate': _fromDateCtrl.text,
          'toDate': _toDateCtrl.text,
          'message': _reasonCtrl.text.trim(),
          if (_hourlyLeave) 'startTime': _fmtTime(_startTime!),
          if (_hourlyLeave) 'endTime': _fmtTime(_endTime!),
        },
      );
      if (mounted) {
        _fromDateCtrl.clear();
        _toDateCtrl.clear();
        _reasonCtrl.clear();
        // Load the refreshed history while still on this tab (offstage) so
        // switching to History shows the final list directly, instead of a
        // spinner-then-list flash on top of the tab switch itself.
        await _loadHistory();
        if (mounted) {
          setState(() {
            _startTime = null;
            _endTime = null;
            _hourlyLeave = false;
            _successMsg = 'Leave request submitted! The hospital admin will be notified.';
            _tab = 2;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractErrorMessage(e, fallback: 'Failed to submit request.')),
          backgroundColor: context.colors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitMessage() async {
    if (_messageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }
    setState(() { _submitting = true; _successMsg = null; });
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).createLeaveRequest(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
        '',
        {
          'leaveType': 'MESSAGE',
          'message': _messageCtrl.text.trim(),
        },
      );
      if (mounted) {
        _messageCtrl.clear();
        // Load the refreshed history while still on this tab (offstage) so
        // switching to History shows the final list directly, instead of a
        // spinner-then-list flash on top of the tab switch itself.
        await _loadHistory();
        if (mounted) {
          setState(() {
            _successMsg = 'Message sent to hospital admin.';
            _tab = 2;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractErrorMessage(e, fallback: 'Failed to send message.')),
          backgroundColor: context.colors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hospital = ref.watch(hospitalProvider);
    final tabs = [tr(ref, 'Leave'), tr(ref, 'Message'), tr(ref, 'History')];

    // Fixed-frame layout: the shell does not scroll. The page header and tab
    // bar are pinned; only the content region below them scrolls. Switching
    // tabs swaps the content in place, so the frame never shifts — even while
    // a backend call is in flight. Each tab keeps its own scroll position.
    return AppShell(
      hospitalName: hospital.hospitalName,
      role: auth.role,
      showBackButton: true,
      onBack: () => context.go('/doctor'),
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: tr(ref, 'Requests'),
            subtitle: tr(ref, 'Apply for leave or send queries to the hospital admin.'),
          ),
          const SizedBox(height: 16),

          // Tab bar
          AppCard(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(tabs.length, (i) {
                final active = _tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _switchTab(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? context.colors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radius - 2),
                      ),
                      child: Text(
                        tabs[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? Colors.white : context.colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabStack(
              index: _tab,
              children: [
                _tabPage(_leaveForm()),
                _tabPage(_messageForm()),
                _tabPage(Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_successMsg != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.colors.mintSoft,
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          border: Border.all(color: context.colors.mint.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.check_circle_outline, color: context.colors.mint, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_successMsg!, style: AppTextStyles.bodyText(context.colors.mintForeground))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _historyList(),
                  ],
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Scrollable content region for one tab — lives below the pinned frame.
  Widget _tabPage(Widget child) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      child: child,
    );
  }

  Widget _leaveForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'Apply for Leave'), style: AppTextStyles.sectionTitle(context.colors.text)),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: tr(ref, 'Leave Type'),
            value: _leaveType,
            items: [
              DropdownMenuItem(value: 'SICK',      child: Text(tr(ref, 'Sick Leave'))),
              DropdownMenuItem(value: 'VACATION',  child: Text(tr(ref, 'Vacation / Planned'))),
              DropdownMenuItem(value: 'EMERGENCY', child: Text(tr(ref, 'Emergency'))),
              DropdownMenuItem(value: 'OTHER',     child: Text(tr(ref, 'Other'))),
            ],
            onChanged: (v) { if (v != null) setState(() => _leaveType = v); },
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_fromDateCtrl),
                  child: AbsorbPointer(
                    child: AppFormField(
                      label: tr(ref, 'From Date'),
                      controller: _fromDateCtrl,
                      placeholder: 'YYYY-MM-DD',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => _pickDate(_toDateCtrl),
                  child: AbsorbPointer(
                    child: AppFormField(
                      label: tr(ref, 'To Date'),
                      controller: _toDateCtrl,
                      placeholder: 'YYYY-MM-DD',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Full day vs hourly leave ─────────────────────────────────────
          Text(tr(ref, 'Duration'), style: AppTextStyles.label(context.colors.textMuted)),
          const SizedBox(height: 6),
          Row(
            children: [
              _DurationChip(
                label: tr(ref, 'Full Day(s)'),
                icon: Icons.today_outlined,
                selected: !_hourlyLeave,
                onTap: () => setState(() => _hourlyLeave = false),
              ),
              const SizedBox(width: 8),
              _DurationChip(
                label: tr(ref, 'Specific Hours'),
                icon: Icons.schedule_outlined,
                selected: _hourlyLeave,
                onTap: () => setState(() => _hourlyLeave = true),
              ),
            ],
          ),
          if (_hourlyLeave) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TimePickTile(
                    label: tr(ref, 'From Time'),
                    value: _startTime == null ? 'Pick time' : _fmtTime(_startTime!),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickTile(
                    label: tr(ref, 'To Time'),
                    value: _endTime == null ? 'Pick time' : _fmtTime(_endTime!),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Only this time window is blocked — you stay bookable for the rest of the day.',
              style: AppTextStyles.label(context.colors.textMuted),
            ),
          ],
          const SizedBox(height: 8),
          AppFormField(
            label: tr(ref, 'Reason / Notes (optional)'),
            controller: _reasonCtrl,
            placeholder: 'Briefly describe the reason…',
            maxLines: 3,
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: tr(ref, 'Submit Leave Request'),
            icon: Icons.send_rounded,
            isLoading: _submitting,
            fullWidth: true,
            onPressed: _submitting ? null : _submitLeave,
          ),
        ],
      ),
    );
  }

  Widget _messageForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'Message to Admin'), style: AppTextStyles.sectionTitle(context.colors.text)),
          const SizedBox(height: 6),
          Text(
            'Send an urgent query, scheduling concern, or any communication to the hospital admin.',
            style: AppTextStyles.bodyText(context.colors.textMuted),
          ),
          const SizedBox(height: 16),
          AppFormField(
            label: tr(ref, 'Message'),
            controller: _messageCtrl,
            placeholder: 'Type your message here…',
            maxLines: 5,
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: tr(ref, 'Send Message'),
            icon: Icons.send_rounded,
            isLoading: _submitting,
            fullWidth: true,
            onPressed: _submitting ? null : _submitMessage,
          ),
        ],
      ),
    );
  }

  Widget _historyList() {
    if (_loadingHistory) {
      return const ShimmerList(count: 3, cardHeight: 84);
    }
    if (_historyError != null) {
      return AppCard(child: Center(child: Text(_historyError!, style: AppTextStyles.bodyText(context.colors.danger))));
    }
    final requests = _history?.requests ?? [];
    if (requests.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.inbox_outlined, size: 48, color: context.colors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(tr(ref, 'No requests yet'), style: AppTextStyles.sectionTitle(context.colors.textMuted)),
            const SizedBox(height: 6),
            Text(tr(ref, 'Submit a leave request or message to see it here.'),
                style: AppTextStyles.bodyText(context.colors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
          ],
        ),
      );
    }
    return Column(
      children: requests.map((r) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _RequestTile(request: r),
      )).toList(),
    );
  }
}

// ── Duration selector chip (Full Day / Specific Hours) ───────────────────────

class _DurationChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? context.colors.primarySoft : context.colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? context.colors.primary : context.colors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15,
                  color: selected ? context.colors.primary : context.colors.textMuted),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.label(
                  selected ? context.colors.primary : context.colors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Time picker tile ──────────────────────────────────────────────────────────

class _TimePickTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimePickTile({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final placeholder = value == 'Pick time';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(context.colors.textMuted)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 15, color: context.colors.textMuted),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: placeholder ? FontWeight.w400 : FontWeight.w600,
                    color: placeholder ? context.colors.textMuted : context.colors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Request history tile ───────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final LeaveRequestRecord request;
  const _RequestTile({required this.request});

  Color _statusColor(BuildContext context) => switch (request.status) {
        'PENDING' => const Color(0xFFD97706),
        'APPROVED' || 'AUTO_APPROVED' => context.colors.mint,
        'DECLINED' => context.colors.danger,
        _ => context.colors.textMuted,
      };

  String get _typeLabel {
    return switch (request.leaveType.toUpperCase()) {
      'SICK'      => 'Sick Leave',
      'VACATION'  => 'Vacation / Planned',
      'EMERGENCY' => 'Emergency Leave',
      'MESSAGE'   => 'Admin Message',
      _           => 'Other Leave',
    };
  }

  String _timeAgo(String? dt) {
    if (dt == null || dt.isEmpty) return '';
    try {
      final parsed = DateTime.parse(dt).toLocal();
      final diff = DateTime.now().difference(parsed);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final isMessage = request.leaveType.toUpperCase() == 'MESSAGE';
    final icon = isMessage ? Icons.chat_bubble_outline : Icons.event_busy_outlined;
    final iconColor = isMessage ? context.colors.primary : context.colors.peachForeground;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(_typeLabel, style: AppTextStyles.cardTitle(context.colors.text))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(context).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            request.status == 'AUTO_APPROVED' ? 'Auto-Approved' : request.status,
                            style: AppTextStyles.badgeText(_statusColor(context)),
                          ),
                        ),
                      ],
                    ),
                    if (!isMessage && request.fromDate != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${request.fromDate}  →  ${request.toDate}'
                        '${request.isHourly ? '  ·  ${request.startTime}–${request.endTime}' : ''}',
                        style: AppTextStyles.label(context.colors.textMuted),
                      ),
                    ],
                    if (request.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(request.message,
                          style: AppTextStyles.bodyText(context.colors.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(_timeAgo(request.submittedAt),
                        style: AppTextStyles.label(context.colors.textMuted)),
                  ],
                ),
              ),
            ],
          ),

          // Admin response box
          if (request.adminResponse != null && request.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.colors.primary.withValues(alpha: 0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      size: 14, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin: ${request.adminResponse!}',
                      style: AppTextStyles.label(context.colors.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
