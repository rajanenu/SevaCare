import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/auto_refresh.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class AdminRequestsScreen extends ConsumerStatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  ConsumerState<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends ConsumerState<AdminRequestsScreen>
    with AutoRefreshMixin {
  int _tab = 0; // 0=Requests (leave + doctor messages), 1=Send Message
  LeaveRequestCollection? _requests;
  bool _loading = true;
  String? _error;

  // Message compose — the target selection lives in the composer sheet; these
  // controllers outlive it so a draft survives dismissing the sheet.
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  List<DoctorRecord> _doctors = [];
  String? _sendSuccess;

  @override
  void initState() {
    super.initState();
    _load();
    startAutoRefresh(() => _load(silent: true));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
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
      if (mounted && !silent) { setState(() => _error = extractErrorMessage(e, fallback: 'Failed to load.')); }
    } finally {
      if (mounted && !silent) { setState(() => _loading = false); }
    }
  }

  Future<void> _action(LeaveRequestRecord req, String action) async {
    final isMessage = req.leaveType.toUpperCase() == 'MESSAGE';
    final responseCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          action == 'APPROVE'
              ? (isMessage ? 'Acknowledge Message' : 'Approve Leave')
              : action == 'DECLINE'
                  ? (isMessage ? 'Dismiss Message' : 'Decline Leave')
                  : (isMessage ? 'Reply' : 'Add Comment'),
          style: AppTextStyles.cardTitle(context.colors.text),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${req.isStaffRequest ? '${req.doctorName} (IP-Staff)' : 'Dr. ${req.doctorName}'}  •  ${isMessage ? 'Message' : req.leaveType}',
                style: AppTextStyles.bodyText(context.colors.textMuted)),
            if (req.fromDate != null) ...[
              const SizedBox(height: 4),
              Text(
                  '${req.fromDate} → ${req.toDate}'
                  '${req.isHourly ? ' · ${req.startTime}–${req.endTime}' : ''}',
                  style: AppTextStyles.label(context.colors.textMuted)),
            ],
            const SizedBox(height: 12),
            AppFormField(
              label: tr(ref, isMessage ? 'Reply (optional)' : 'Response / Comment (optional)'),
              controller: responseCtrl,
              placeholder: isMessage ? 'Write a reply to the doctor…' : 'Add a message to the doctor…',
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(ref, 'Cancel'), style: AppTextStyles.label(context.colors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'DECLINE' ? context.colors.danger : context.colors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action == 'APPROVE'
                  ? tr(ref, isMessage ? 'Acknowledge' : 'Approve')
                  : action == 'DECLINE'
                      ? tr(ref, isMessage ? 'Dismiss' : 'Decline')
                      : tr(ref, 'Send'),
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
          backgroundColor: context.colors.danger,
        ));
      }
    }
  }

  /// Returns true when the message went out, so the composer sheet knows
  /// whether to close itself.
  Future<bool> _sendMessage({
    required String targetType,
    String? targetSpecialty,
    String? targetDoctorId,
  }) async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and message are required.')),
      );
      return false;
    }
    if (targetType == 'DEPARTMENT' && (targetSpecialty == null || targetSpecialty.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a department.')),
      );
      return false;
    }
    if (targetType == 'INDIVIDUAL' && (targetDoctorId == null || targetDoctorId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor.')),
      );
      return false;
    }
    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).sendAdminMessage(
        auth.tenantPublicId ?? '',
        auth.token ?? '',
        title:           _titleCtrl.text.trim(),
        body:            _bodyCtrl.text.trim(),
        targetType:      targetType,
        targetSpecialty: targetSpecialty,
        targetDoctorId:  targetDoctorId,
      );
      _sendSuccess = switch (targetType) {
        'ALL'        => 'Message sent to all doctors.',
        'DEPARTMENT' => 'Message sent to $targetSpecialty department.',
        _            => 'Message sent to selected doctor.',
      };
      _titleCtrl.clear();
      _bodyCtrl.clear();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: ${extractErrorMessage(e)}'),
          backgroundColor: context.colors.danger,
        ));
      }
      return false;
    }
  }

  List<String> get _uniqueSpecialties {
    final set = <String>{};
    for (final d in _doctors) {
      if (d.specialty.isNotEmpty) set.add(d.specialty);
    }
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests?.requests.where((r) => r.status == 'PENDING').length ?? 0;

    // Fixed-frame layout: the section header and sub-tab bar are pinned;
    // only the content region below scrolls. Switching sub-tabs swaps the
    // content in place, so nothing above it ever moves. Requires a bounded
    // height from the parent (the admin dashboard's tab area provides one).
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: tr(ref, 'Requests & Messages'),
          subtitle: pending > 0
              ? '$pending request(s) awaiting your action'
              : tr(ref, 'All requests up to date'),
        ),
        const SizedBox(height: 16),

        // Tab bar
        AppCard(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _TabBtn(
                label: tr(ref, 'Requests'),
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

        Expanded(
          child: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: [
              SingleChildScrollView(
                primary: false,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildLeaveTab(),
              ),
              SingleChildScrollView(
                primary: false,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildMessageTab(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveTab() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(count: 4, cardHeight: 92),
      );
    }
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }

    final requests = _requests?.requests ?? [];
    if (requests.isEmpty) {
      return AppCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Icon(Icons.inbox_outlined, size: 44, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(tr(ref, 'No leave requests'), style: AppTextStyles.sectionTitle(context.colors.textMuted)),
            const SizedBox(height: 6),
            Text(tr(ref, "Doctors' leave requests will appear here."),
                style: AppTextStyles.bodyText(context.colors.textMuted),
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

  /// The compose form used to live inline in this tab. Between the dashboard's
  /// header and tab strip, this screen's own header and tab strip, and the
  /// bottom nav, the form was left a sliver of height — and with the keyboard
  /// open the Title and Message fields collapsed to a couple of pixels. The
  /// form now owns a full-height sheet where nothing competes for the space.
  Widget _buildMessageTab() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: context.colors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.campaign_outlined,
                  size: 21, color: context.colors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(ref, 'Message your doctors'),
                    style: AppTextStyles.cardTitle(context.colors.text)),
                const SizedBox(height: 2),
                Text(tr(ref, 'Reach everyone, one department, or a single doctor.'),
                    style: AppTextStyles.label(context.colors.textMuted)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),

          if (_sendSuccess != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.mintSoft,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: context.colors.mint.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_outline, color: context.colors.mint, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_sendSuccess!,
                    style: AppTextStyles.bodyText(context.colors.mintForeground))),
              ]),
            ),
            const SizedBox(height: 12),
          ],

          PrimaryButton(
            label: tr(ref, 'Compose Message'),
            icon: Icons.edit_outlined,
            fullWidth: true,
            onPressed: _doctors.isEmpty ? null : _openComposer,
          ),
          if (_doctors.isEmpty) ...[
            const SizedBox(height: 10),
            Text(tr(ref, 'Add a doctor before you can send messages.'),
                style: AppTextStyles.label(context.colors.textMuted)),
          ],
        ],
      ),
    );
  }

  Future<void> _openComposer() async {
    setState(() => _sendSuccess = null);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MessageComposerSheet(
        titleCtrl: _titleCtrl,
        bodyCtrl: _bodyCtrl,
        specialties: _uniqueSpecialties,
        doctors: _doctors,
        onSend: _sendMessage,
      ),
    );
    if (mounted) setState(() {});
  }
}

// ── Test seam ──────────────────────────────────────────────────────────────────

/// The composer normally opens as a modal sheet from [AdminRequestsScreen].
/// Widget tests need it standalone to assert the Title/Message fields keep a
/// usable height when the keyboard is up.
@visibleForTesting
Widget buildMessageComposerForTest({
  required TextEditingController titleCtrl,
  required TextEditingController bodyCtrl,
  List<String> specialties = const [],
  List<DoctorRecord> doctors = const [],
}) {
  return _MessageComposerSheet(
    titleCtrl: titleCtrl,
    bodyCtrl: bodyCtrl,
    specialties: specialties,
    doctors: doctors,
    onSend: ({required targetType, targetSpecialty, targetDoctorId}) async => true,
  );
}

// ── Full-height message composer ───────────────────────────────────────────────

/// Owns its own target selection so typing never rebuilds the screen behind it.
/// Sits on top of the keyboard and claims the height that is left, so the Title
/// and Message fields keep their full size no matter what else is on screen.
class _MessageComposerSheet extends ConsumerStatefulWidget {
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final List<String> specialties;
  final List<DoctorRecord> doctors;
  final Future<bool> Function({
    required String targetType,
    String? targetSpecialty,
    String? targetDoctorId,
  }) onSend;

  const _MessageComposerSheet({
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.specialties,
    required this.doctors,
    required this.onSend,
  });

  @override
  ConsumerState<_MessageComposerSheet> createState() => _MessageComposerSheetState();
}

class _MessageComposerSheetState extends ConsumerState<_MessageComposerSheet> {
  // ALL | DEPARTMENT | INDIVIDUAL
  String  _targetType = 'ALL';
  String? _filterSpecialty;
  String? _targetDoctorId;
  bool    _sending = false;

  List<DoctorRecord> get _filteredDoctors => _filterSpecialty == null
      ? widget.doctors
      : widget.doctors.where((d) => d.specialty == _filterSpecialty).toList();

  Future<void> _submit() async {
    setState(() => _sending = true);
    final sent = await widget.onSend(
      targetType:      _targetType,
      targetSpecialty: _filterSpecialty,
      targetDoctorId:  _targetType == 'INDIVIDUAL' ? _targetDoctorId : null,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (sent) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final available = media.size.height - media.padding.top - keyboardInset;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: available * 0.94,
        child: Column(
          children: [
            // Grab handle + title bar are pinned; only the form scrolls.
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(children: [
                Expanded(child: Text(tr(ref, 'New Message'),
                    style: AppTextStyles.sectionTitle(context.colors.text))),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.colors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(ref, 'Send to'),
                        style: AppTextStyles.label(context.colors.textMuted)),
                    const SizedBox(height: 8),

                    // ── Target type selector (3 chips) ──────────────────────
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
                    const SizedBox(height: 16),

                    // ── Department / Specialty filter ───────────────────────
                    if (_targetType == 'DEPARTMENT' || _targetType == 'INDIVIDUAL')
                      AppDropdown<String?>(
                        label: _targetType == 'DEPARTMENT'
                            ? tr(ref, 'Select Department')
                            : tr(ref, 'Filter by Specialty (optional)'),
                        value: _filterSpecialty,
                        items: [
                          DropdownMenuItem<String?>(
                              value: null, child: Text(tr(ref, '— All Departments —'))),
                          ...widget.specialties.map((s) =>
                              DropdownMenuItem<String?>(value: s, child: Text(s))),
                        ],
                        onChanged: (v) => setState(() {
                          _filterSpecialty = v;
                          _targetDoctorId  = null; // reset doctor on specialty change
                        }),
                      ),

                    // ── Individual doctor picker ────────────────────────────
                    if (_targetType == 'INDIVIDUAL')
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

                    AppFormField(
                      label: tr(ref, 'Title'),
                      controller: widget.titleCtrl,
                      placeholder: 'e.g. Schedule Change for Next Week',
                      required: true,
                    ),
                    AppFormField(
                      label: tr(ref, 'Message'),
                      controller: widget.bodyCtrl,
                      placeholder: 'Write your message to the doctor(s)…',
                      maxLines: 6,
                      required: true,
                    ),
                  ],
                ),
              ),
            ),

            // Send action pinned above the keyboard, never over the form.
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              child: PrimaryButton(
                label: switch (_targetType) {
                  'ALL'        => 'Send to All Doctors',
                  'DEPARTMENT' => 'Send to Department',
                  _            => 'Send to Doctor',
                },
                icon: Icons.send_rounded,
                isLoading: _sending,
                fullWidth: true,
                onPressed: _sending ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Leave request card ─────────────────────────────────────────────────────────

class _LeaveRequestCard extends ConsumerWidget {
  final LeaveRequestRecord request;
  final void Function(String action) onAction;

  const _LeaveRequestCard({required this.request, required this.onAction});

  Color _statusColor(BuildContext context) => switch (request.status) {
        'PENDING' => const Color(0xFFD97706),
        'APPROVED' || 'AUTO_APPROVED' => context.colors.mint,
        'DECLINED' => context.colors.danger,
        _ => context.colors.textMuted,
      };
  bool  get _isPending   => request.status == 'PENDING';
  bool  get _isMessage   => request.leaveType.toUpperCase() == 'MESSAGE';

  // Messages read as a conversation item, not a leave to approve — so they get
  // their own icon, accent color, chip and button labels.
  Color _accent(BuildContext context) => _isMessage ? const Color(0xFF2563EB) : context.colors.primary;

  String _typeLabel(WidgetRef ref) => switch (request.leaveType.toUpperCase()) {
    'SICK'      => tr(ref, 'Sick Leave'),
    'VACATION'  => tr(ref, 'Vacation'),
    'EMERGENCY' => tr(ref, 'Emergency'),
    'MESSAGE'   => tr(ref, 'Message'),
    _           => tr(ref, 'Other Leave'),
  };

  String _statusLabel() {
    if (_isMessage && (request.status == 'APPROVED' || request.status == 'AUTO_APPROVED')) {
      return 'ACKNOWLEDGED';
    }
    return request.status.replaceAll('_', ' ');
  }

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
                color: _accent(context).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  _isMessage ? Icons.chat_bubble_outline_rounded : Icons.event_busy_outlined,
                  size: 20, color: _accent(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    request.isStaffRequest
                        ? request.doctorName
                        : 'Dr. ${request.doctorName}',
                    style: AppTextStyles.cardTitle(context.colors.text)),
                Text(
                    request.isStaffRequest ? '${_typeLabel(ref)} · IP-Staff' : _typeLabel(ref),
                    style: AppTextStyles.label(_isMessage ? _accent(context) : context.colors.textMuted)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(_statusLabel(),
                  style: AppTextStyles.badgeText(_statusColor(context))),
            ),
          ]),

          // ── Date range ──────────────────────────────────────────────────────
          if (request.fromDate != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: context.colors.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.date_range_outlined, size: 14,
                    color: context.colors.textMuted),
                const SizedBox(width: 6),
                Text(
                    '${request.fromDate}  →  ${request.toDate}'
                    '${request.isHourly ? '  ·  ${request.startTime}–${request.endTime}' : ''}',
                    style: AppTextStyles.label(context.colors.textMuted)),
              ]),
            ),
          ],

          // ── Message ─────────────────────────────────────────────────────────
          if (request.message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(request.message,
                style: AppTextStyles.bodyText(context.colors.textMuted),
                maxLines: 3, overflow: TextOverflow.ellipsis),
          ],

          // ── Admin response ───────────────────────────────────────────────────
          if (request.adminResponse != null && request.adminResponse!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(Icons.admin_panel_settings_outlined,
                    size: 14, color: context.colors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(request.adminResponse!,
                    style: AppTextStyles.label(context.colors.primary))),
              ]),
            ),
          ],

          // ── Action buttons (only for PENDING) ───────────────────────────────
          if (_isPending) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            if (_isMessage) ...[
              // Messages: Reply + Acknowledge — no decline, a message isn't a
              // leave to approve or reject.
              Row(children: [
                Expanded(
                  child: _ActionBtn(
                    label: tr(ref, 'Reply'),
                    icon: Icons.reply_rounded,
                    color: _accent(context),
                    filled: false,
                    onTap: () => onAction('COMMENT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: tr(ref, 'Acknowledge'),
                    icon: Icons.mark_chat_read_outlined,
                    color: context.colors.mint,
                    filled: true,
                    onTap: () => onAction('APPROVE'),
                  ),
                ),
              ]),
            ] else ...[
              // Row 1: Comment + Decline (secondary, equal width)
              Row(children: [
                Expanded(
                  child: _ActionBtn(
                    label: tr(ref, 'Comment'),
                    icon: Icons.comment_outlined,
                    color: context.colors.primary,
                    filled: false,
                    onTap: () => onAction('COMMENT'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionBtn(
                    label: tr(ref, 'Decline'),
                    icon: Icons.close_rounded,
                    color: context.colors.danger,
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
                color: context.colors.mint,
                filled: true,
                fullWidth: true,
                onTap: () => onAction('APPROVE'),
              ),
            ],
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
            color: active ? context.colors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radius - 2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active ? Colors.white : context.colors.textMuted,
                  )),
              if (badge != null && badge! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : context.colors.danger,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$badge',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: active ? context.colors.primary : Colors.white,
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
          color: selected ? context.colors.primarySoft : context.colors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: selected
                ? context.colors.primary.withValues(alpha: 0.35)
                : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18,
                color: selected ? context.colors.primary : context.colors.textMuted),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? context.colors.primary : context.colors.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}
