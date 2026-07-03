import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  ConsumerState<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen> {
  int _tab = 0; // 0=Leave Requests, 1=Send Message
  LeaveRequestCollection? _requests;
  bool _loading = true;
  String? _error;

  // Message compose
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  // ALL | DEPARTMENT | INDIVIDUAL
  String  _targetType      = 'ALL';
  String? _filterSpecialty;   // for DEPARTMENT + INDIVIDUAL
  String? _targetDoctorId;    // for INDIVIDUAL
  List<DoctorRecord> _doctors = [];
  bool    _sending    = false;
  String? _sendSuccess;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final results = await Future.wait([
        repo.getAdminLeaveRequests(auth.tenantPublicId ?? '', auth.token ?? ''),
        repo.listDoctorRecords(auth.tenantPublicId ?? '', auth.token ?? ''),
      ]);
      if (mounted) {
        setState(() {
          _requests = results[0] as LeaveRequestCollection;
          _doctors  = results[1] as List<DoctorRecord>;
        });
      }
    } catch (e) {
      if (mounted) { setState(() => _error = extractErrorMessage(e, fallback: 'Failed to load.')); }
    } finally {
      if (mounted) { setState(() => _loading = false); }
    }
  }

  Future<void> _action(LeaveRequestRecord req, String action) async {
    final responseCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text(
          action == 'APPROVE' ? 'Approve Leave' : action == 'DECLINE' ? 'Decline Leave' : 'Add Comment',
          style: AppTextStyles.cardTitle(SevaCareColors.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${req.isStaffRequest ? '${req.doctorName} (IP-Staff)' : 'Dr. ${req.doctorName}'}  •  ${req.leaveType}',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
            if (req.fromDate != null) ...[
              const SizedBox(height: 4),
              Text(
                  '${req.fromDate} → ${req.toDate}'
                  '${req.isHourly ? ' · ${req.startTime}–${req.endTime}' : ''}',
                  style: AppTextStyles.label(SevaCareColors.textMuted)),
            ],
            const SizedBox(height: 12),
            AppFormField(
              label: tr(ref, 'Response / Comment (optional)'),
              controller: responseCtrl,
              placeholder: 'Add a message to the doctor…',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ref, 'Cancel'), style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'DECLINE' ? SevaCareColors.danger : SevaCareColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action == 'APPROVE' ? tr(ref, 'Approve') : action == 'DECLINE' ? tr(ref, 'Decline') : tr(ref, 'Send'),
              style: AppTextStyles.label(Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).actionLeaveRequest(
        auth.tenantPublicId ?? '',
        req.requestPublicId,
        auth.token ?? '',
        action,
        responseCtrl.text.trim().isEmpty ? null : responseCtrl.text.trim(),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${extractErrorMessage(e)}'),
          backgroundColor: SevaCareColors.danger,
        ));
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return;
    }
    if (_targetType == 'DEPARTMENT' && (_filterSpecialty == null || _filterSpecialty!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department.')),
      );
      return;
    }
    if (_targetType == 'INDIVIDUAL' && (_targetDoctorId == null || _targetDoctorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor.')),
      );
      return;
    }
    setState(() { _sending = true; _sendSuccess = null; });
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).sendAdminMessage(
        auth.tenantPublicId ?? '',
        auth.token ?? '',
        title:          _titleCtrl.text.trim(),
        body:           _bodyCtrl.text.trim(),
        targetType:     _targetType,
        targetSpecialty: _filterSpecialty,
        targetDoctorId: _targetType == 'INDIVIDUAL' ? _targetDoctorId : null,
      );
      if (mounted) {
        setState(() {
          _sendSuccess = switch (_targetType) {
            'ALL'        => 'Message sent to all doctors.',
            'DEPARTMENT' => 'Message sent to $_filterSpecialty department.',
            _            => 'Message sent to selected doctor.',
          };
          _titleCtrl.clear();
          _bodyCtrl.clear();
          _filterSpecialty = null;
          _targetDoctorId  = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${extractErrorMessage(e)}'),
          backgroundColor: SevaCareColors.danger,
        ));
      }
    } finally {
      if (mounted) { setState(() => _sending = false); }
    }
  }

  List<String> get _uniqueSpecialties {
    final set = <String>{};
    for (final d in _doctors) {
      if (d.specialty.isNotEmpty) set.add(d.specialty);
    }
    return set.toList()..sort();
  }

  List<DoctorRecord> get _filteredDoctors => _filterSpecialty == null
      ? _doctors
      : _doctors.where((d) => d.specialty == _filterSpecialty).toList();

  @override
  Widget build(BuildContext context) {
    final pending = _requests?.requests.where((r) => r.status == 'PENDING').length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: tr(ref, 'Requests & Messages'),
          subtitle: pending > 0
              ? '$pending leave request(s) pending approval'
              : tr(ref, 'All leave requests up to date'),
        ),
        const SizedBox(height: 16),

        // Tab bar
        AppCard(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _TabBtn(
                label: tr(ref, 'Leave Requests'),
                active: _tab == 0,
                badge: pending > 0 ? pending : null,
                onTap: () => setState(() => _tab = 0),
              ),
              _TabBtn(
                label: tr(ref, 'Send Message'),
                active: _tab == 1,
                onTap: () => setState(() => _tab = 1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_tab == 0) _buildLeaveTab() else _buildMessageTab(),
      ],
    );
  }

  Widget _buildLeaveTab() {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.error_outline, color: SevaCareColors.danger),
            const SizedBox(height: 8),
            Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
            const SizedBox(height: 12),
            PrimaryButton(label: tr(ref, 'Retry'), onPressed: _load),
          ]),
        ),
      );
    }

    final requests = _requests?.requests ?? [];
    if (requests.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const Icon(Icons.inbox_outlined, size: 44, color: SevaCareColors.textMuted),
            const SizedBox(height: 12),
            Text(tr(ref, 'No leave requests'), style: AppTextStyles.sectionTitle(SevaCareColors.textMuted)),
            const SizedBox(height: 6),
            Text(tr(ref, "Doctors' leave requests will appear here."),
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return Column(
      children: requests.map((req) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _LeaveRequestCard(request: req, onAction: (action) => _action(req, action)),
      )).toList(),
    );
  }

  Widget _buildMessageTab() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(ref, 'Broadcast / Direct Message'), style: AppTextStyles.sectionTitle(SevaCareColors.text)),
          const SizedBox(height: 4),
          Text(
            tr(ref, 'Send a notification to all doctors, a department, or a specific doctor.'),
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
          const SizedBox(height: 16),

          // ── Target type selector (3 chips) ──────────────────────────────────
          Row(children: [
            Expanded(child: _TargetChip(
              label: tr(ref, 'All'),
              icon: Icons.groups_outlined,
              selected: _targetType == 'ALL',
              onTap: () => setState(() {
                _targetType = 'ALL';
                _filterSpecialty = null;
                _targetDoctorId  = null;
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TargetChip(
              label: tr(ref, 'Dept.'),
              icon: Icons.business_outlined,
              selected: _targetType == 'DEPARTMENT',
              onTap: () => setState(() {
                _targetType = 'DEPARTMENT';
                _targetDoctorId = null;
              }),
            )),
            const SizedBox(width: 8),
            Expanded(child: _TargetChip(
              label: tr(ref, 'Doctor'),
              icon: Icons.person_outline,
              selected: _targetType == 'INDIVIDUAL',
              onTap: () => setState(() => _targetType = 'INDIVIDUAL'),
            )),
          ]),
          const SizedBox(height: 12),

          // ── Department / Specialty filter (DEPARTMENT + INDIVIDUAL) ──────────
          if (_targetType == 'DEPARTMENT' || _targetType == 'INDIVIDUAL') ...[
            AppDropdown<String?>(
              label: _targetType == 'DEPARTMENT'
                  ? tr(ref, 'Select Department')
                  : tr(ref, 'Filter by Specialty (optional)'),
              value: _filterSpecialty,
              items: [
                DropdownMenuItem<String?>(
                    value: null, child: Text(tr(ref, '— All Departments —'))),
                ..._uniqueSpecialties.map((s) =>
                    DropdownMenuItem<String?>(value: s, child: Text(s))),
              ],
              onChanged: (v) => setState(() {
                _filterSpecialty = v;
                _targetDoctorId  = null; // reset doctor on specialty change
              }),
            ),
            const SizedBox(height: 4),
          ],

          // ── Individual doctor picker ─────────────────────────────────────────
          if (_targetType == 'INDIVIDUAL') ...[
            AppDropdown<String>(
              label: tr(ref, 'Select Doctor'),
              value: _targetDoctorId ?? '',
              items: [
                DropdownMenuItem(value: '', child: Text(tr(ref, '— Select Doctor —'))),
                ..._filteredDoctors.map((d) => DropdownMenuItem(
                  value: d.doctorPublicId,
                  child: Text('Dr. ${d.fullName}'),
                )),
              ],
              onChanged: (v) => setState(
                  () => _targetDoctorId = (v == null || v.isEmpty) ? null : v),
            ),
            const SizedBox(height: 4),
          ],

          AppFormField(
            label: tr(ref, 'Title'),
            controller: _titleCtrl,
            placeholder: 'e.g. Schedule Change for Next Week',
          ),
          AppFormField(
            label: tr(ref, 'Message'),
            controller: _bodyCtrl,
            placeholder: 'Write your message to the doctor(s)…',
            maxLines: 4,
          ),
          const SizedBox(height: 4),

          if (_sendSuccess != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SevaCareColors.mintSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: SevaCareColors.mint.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: SevaCareColors.mint, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_sendSuccess!,
                    style: AppTextStyles.bodyText(SevaCareColors.mintForeground))),
              ]),
            ),
            const SizedBox(height: 10),
          ],

          PrimaryButton(
            label: switch (_targetType) {
              'ALL'        => 'Send to All Doctors',
              'DEPARTMENT' => 'Send to Department',
              _            => 'Send to Doctor',
            },
            icon: Icons.send_rounded,
            isLoading: _sending,
            fullWidth: true,
            onPressed: _sending ? null : _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ── Leave request card ─────────────────────────────────────────────────────────

class _LeaveRequestCard extends ConsumerWidget {
  final LeaveRequestRecord request;
  final void Function(String action) onAction;

  const _LeaveRequestCard({required this.request, required this.onAction});

  static final _statusColors = <String, Color>{
    'PENDING':      Color(0xFFD97706),
    'APPROVED':     SevaCareColors.mint,
    'AUTO_APPROVED': SevaCareColors.mint,
    'DECLINED':     SevaCareColors.danger,
  };

  Color get _statusColor => _statusColors[request.status] ?? SevaCareColors.textMuted;
  bool  get _isPending   => request.status == 'PENDING';

  String _typeLabel(WidgetRef ref) => switch (request.leaveType.toUpperCase()) {
    'SICK'      => tr(ref, 'Sick Leave'),
    'VACATION'  => tr(ref, 'Vacation'),
    'EMERGENCY' => tr(ref, 'Emergency'),
    'MESSAGE'   => tr(ref, 'Query'),
    _           => tr(ref, 'Other Leave'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: SevaCareColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.event_busy_outlined, size: 20,
                  color: SevaCareColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    request.isStaffRequest
                        ? request.doctorName
                        : 'Dr. ${request.doctorName}',
                    style: AppTextStyles.cardTitle(SevaCareColors.text)),
                Text(
                    request.isStaffRequest ? '${_typeLabel(ref)} · IP-Staff' : _typeLabel(ref),
                    style: AppTextStyles.label(SevaCareColors.textMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(request.status.replaceAll('_', ' '),
                  style: AppTextStyles.badgeText(_statusColor)),
            ),
          ]),

          // ── Date range ──────────────────────────────────────────────────────
          if (request.fromDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SevaCareColors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.date_range_outlined, size: 14,
                    color: SevaCareColors.textMuted),
                const SizedBox(width: 6),
                Text(
                    '${request.fromDate}  →  ${request.toDate}'
                    '${request.isHourly ? '  ·  ${request.startTime}–${request.endTime}' : ''}',
                    style: AppTextStyles.label(SevaCareColors.textMuted)),
              ]),
            ),
          ],

          // ── Message ─────────────────────────────────────────────────────────
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.message,
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],

          // ── Admin response ───────────────────────────────────────────────────
          if (request.adminResponse != null && request.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.admin_panel_settings_outlined,
                    size: 14, color: SevaCareColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(request.adminResponse!,
                    style: AppTextStyles.label(SevaCareColors.primary))),
              ]),
            ),
          ],

          // ── Action buttons (only for PENDING) ───────────────────────────────
          if (_isPending) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Row 1: Comment + Decline (secondary, equal width)
            Row(children: [
              Expanded(
                child: _ActionBtn(
                  label: tr(ref, 'Comment'),
                  icon: Icons.comment_outlined,
                  color: SevaCareColors.primary,
                  filled: false,
                  onTap: () => onAction('COMMENT'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  label: tr(ref, 'Decline'),
                  icon: Icons.close_rounded,
                  color: SevaCareColors.danger,
                  filled: false,
                  onTap: () => onAction('DECLINE'),
                ),
              ),
            ]),
            const SizedBox(height: 8),

            // Row 2: Approve (primary, full width)
            _ActionBtn(
              label: tr(ref, 'Approve Leave'),
              icon: Icons.check_circle_outline_rounded,
              color: SevaCareColors.mint,
              filled: true,
              fullWidth: true,
              onTap: () => onAction('APPROVE'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Compact action button ──────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  final bool     filled;
  final bool     fullWidth;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.filled,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final Widget inner = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? Colors.transparent : color.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: filled ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
    return inner;
  }
}

// ── Tab button ─────────────────────────────────────────────────────────────────

class _TabBtn extends StatelessWidget {
  final String     label;
  final bool       active;
  final int?       badge;
  final VoidCallback onTap;

  const _TabBtn({required this.label, required this.active,
      required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? SevaCareColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius - 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? Colors.white : SevaCareColors.textMuted,
                  )),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : SevaCareColors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$badge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active ? SevaCareColors.primary : Colors.white,
                        )),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Target chip ────────────────────────────────────────────────────────────────

class _TargetChip extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final bool       selected;
  final VoidCallback onTap;

  const _TargetChip({required this.label, required this.icon,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? SevaCareColors.primarySoft : SevaCareColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected
                ? SevaCareColors.primary.withValues(alpha: 0.35)
                : SevaCareColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18,
                color: selected ? SevaCareColors.primary : SevaCareColors.textMuted),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? SevaCareColors.primary : SevaCareColors.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}
