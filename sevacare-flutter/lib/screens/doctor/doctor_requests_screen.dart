import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class DoctorRequestsScreen extends ConsumerStatefulWidget {
  const DoctorRequestsScreen({super.key});

  @override
  ConsumerState<DoctorRequestsScreen> createState() => _DoctorRequestsScreenState();
}

class _DoctorRequestsScreenState extends ConsumerState<DoctorRequestsScreen> {
  int _tab = 0; // 0=Leave, 1=Message Admin, 2=History

  final _messageCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _fromDateCtrl = TextEditingController();
  final _toDateCtrl = TextEditingController();
  String _leaveType = 'SICK';
  bool _submitting = false;
  String? _successMsg;

  LeaveRequestCollection? _history;
  bool _loadingHistory = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _reasonCtrl.dispose();
    _fromDateCtrl.dispose();
    _toDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() { _loadingHistory = true; _historyError = null; });
    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(repositoryProvider).getDoctorLeaveRequests(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
      );
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) setState(() => _historyError = extractErrorMessage(e, fallback: 'Failed to load history.'));
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
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

  Future<void> _submitLeave() async {
    if (_fromDateCtrl.text.isEmpty || _toDateCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select from and to dates.')),
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
        '', // adminPublicId — backend resolves from tenant
        {
          'leaveType': _leaveType,
          'fromDate': _fromDateCtrl.text,
          'toDate': _toDateCtrl.text,
          'message': _reasonCtrl.text.trim(),
        },
      );
      if (mounted) {
        _fromDateCtrl.clear();
        _toDateCtrl.clear();
        _reasonCtrl.clear();
        setState(() {
          _successMsg = 'Leave request submitted! The hospital admin will be notified.';
          _tab = 2;
        });
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractErrorMessage(e, fallback: 'Failed to submit request.')),
          backgroundColor: SevaCareColors.danger,
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
        setState(() {
          _successMsg = 'Message sent to hospital admin.';
          _tab = 2;
        });
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractErrorMessage(e, fallback: 'Failed to send message.')),
          backgroundColor: SevaCareColors.danger,
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
    final tabs = ['Leave Request', 'Message Admin', 'History'];

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: auth.role,
      showBackButton: true,
      onBack: () => context.go('/doctor'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Requests',
            subtitle: 'Apply for leave or send queries to the hospital admin.',
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
                    onTap: () => setState(() { _tab = i; _successMsg = null; }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: active ? SevaCareColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppTheme.radius - 2),
                      ),
                      child: Text(
                        tabs[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                          color: active ? Colors.white : SevaCareColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          if (_successMsg != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SevaCareColors.mintSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: SevaCareColors.mint.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: SevaCareColors.mint, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_successMsg!, style: AppTextStyles.bodyText(SevaCareColors.mintForeground))),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: _tab == 0
                  ? _leaveForm()
                  : _tab == 1
                      ? _messageForm()
                      : _historyList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apply for Leave', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'Leave Type',
            value: _leaveType,
            items: const [
              DropdownMenuItem(value: 'SICK',      child: Text('Sick Leave')),
              DropdownMenuItem(value: 'VACATION',  child: Text('Vacation / Planned')),
              DropdownMenuItem(value: 'EMERGENCY', child: Text('Emergency')),
              DropdownMenuItem(value: 'OTHER',     child: Text('Other')),
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
                      label: 'From Date',
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
                      label: 'To Date',
                      controller: _toDateCtrl,
                      placeholder: 'YYYY-MM-DD',
                    ),
                  ),
                ),
              ),
            ],
          ),
          AppFormField(
            label: 'Reason / Notes (optional)',
            controller: _reasonCtrl,
            placeholder: 'Briefly describe the reason…',
            maxLines: 3,
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Submit Leave Request',
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
          Text('Message to Admin', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
          const SizedBox(height: 6),
          Text(
            'Send an urgent query, scheduling concern, or any communication to the hospital admin.',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
          const SizedBox(height: 16),
          AppFormField(
            label: 'Message',
            controller: _messageCtrl,
            placeholder: 'Type your message here…',
            maxLines: 5,
          ),
          const SizedBox(height: 4),
          PrimaryButton(
            label: 'Send Message',
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
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    if (_historyError != null) {
      return AppCard(child: Center(child: Text(_historyError!, style: AppTextStyles.bodyText(SevaCareColors.danger))));
    }
    final requests = _history?.requests ?? [];
    if (requests.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.inbox_outlined, size: 48, color: SevaCareColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text('No requests yet', style: AppTextStyles.sectionTitle(SevaCareColors.textMuted)),
            const SizedBox(height: 6),
            Text('Submit a leave request or message to see it here.',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
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

// ── Request history tile ───────────────────────────────────────────────────────

class _RequestTile extends StatelessWidget {
  final LeaveRequestRecord request;
  const _RequestTile({required this.request});

  static final _statusColors = <String, Color>{
    'PENDING':      Color(0xFFD97706),
    'APPROVED':     SevaCareColors.mint,
    'AUTO_APPROVED': SevaCareColors.mint,
    'DECLINED':     SevaCareColors.danger,
  };

  Color get _statusColor => _statusColors[request.status] ?? SevaCareColors.textMuted;

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
    final iconColor = isMessage ? SevaCareColors.primary : SevaCareColors.peachForeground;

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
                        Expanded(child: Text(_typeLabel, style: AppTextStyles.cardTitle(SevaCareColors.text))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            request.status == 'AUTO_APPROVED' ? 'Auto-Approved' : request.status,
                            style: AppTextStyles.badgeText(_statusColor),
                          ),
                        ),
                      ],
                    ),
                    if (!isMessage && request.fromDate != null) ...[
                      const SizedBox(height: 4),
                      Text('${request.fromDate}  →  ${request.toDate}',
                          style: AppTextStyles.label(SevaCareColors.textMuted)),
                    ],
                    if (request.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(request.message,
                          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Text(_timeAgo(request.submittedAt),
                        style: AppTextStyles.label(SevaCareColors.textMuted)),
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
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SevaCareColors.primary.withValues(alpha: 0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.admin_panel_settings_outlined,
                      size: 14, color: SevaCareColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Admin: ${request.adminResponse!}',
                      style: AppTextStyles.label(SevaCareColors.primary),
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
