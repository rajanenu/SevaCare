import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/auto_refresh.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// Doctor-facing inbox of appointment requests from the hospital QR code and
/// the chatbot. Requests are auto-confirmed with the next available token on
/// submission — pending ones only appear when auto-confirm failed (e.g. the
/// doctor was on leave) and can still be confirmed manually here.
class DoctorAppointmentRequestsScreen extends ConsumerStatefulWidget {
  const DoctorAppointmentRequestsScreen({super.key});

  @override
  ConsumerState<DoctorAppointmentRequestsScreen> createState() =>
      _DoctorAppointmentRequestsScreenState();
}

class _DoctorAppointmentRequestsScreenState
    extends ConsumerState<DoctorAppointmentRequestsScreen> with AutoRefreshMixin {
  AppointmentRequestCollection? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    startAutoRefresh(() => _load(silent: true));
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(repositoryProvider).getDoctorAppointmentRequests(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            auth.token ?? '',
          );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _error = extractErrorMessage(e, fallback: 'Failed to load booking requests.'));
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  Future<void> _confirm(AppointmentRequest req) async {
    final result = await showDialog<_ConfirmResult>(
      context: context,
      builder: (_) => _ConfirmDialog(request: req),
    );
    if (result == null) return;

    try {
      final auth = ref.read(authProvider);
      await ref.read(repositoryProvider).confirmDoctorAppointmentRequest(
            auth.tenantPublicId ?? '',
            auth.subjectPublicId ?? '',
            req.requestPublicId,
            auth.token ?? '',
            bookingType: result.bookingType,
            slot: result.slot,
            tokenSession: result.tokenSession,
            notes: result.notes,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Appointment confirmed for ${req.patientName}.'),
          backgroundColor: SevaCareColors.mint,
        ));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(extractErrorMessage(e, fallback: 'Failed to confirm request.')),
          backgroundColor: SevaCareColors.danger,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hospital = ref.watch(hospitalProvider);
    final requests = _data?.requests ?? [];
    final pending = requests.where((r) => r.isPending).length;

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: auth.role,
      showBackButton: true,
      onBack: () => context.go('/doctor'),
      scrollable: false,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            PageHeader(
              title: 'Booking Requests',
              subtitle: pending > 0
                  ? '$pending request${pending == 1 ? '' : 's'} need${pending == 1 ? 's' : ''} manual confirmation'
                  : 'QR & chatbot bookings — auto-confirmed with a token',
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _ErrorBox(message: _error!, onRetry: _load)
            else if (requests.isEmpty)
              const _EmptyBox()
            else
              ...requests.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _RequestCard(request: r, onConfirm: () => _confirm(r)),
                  )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Request card ────────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final AppointmentRequest request;
  final VoidCallback onConfirm;

  const _RequestCard({required this.request, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final pending = request.isPending;
    final statusColor = pending ? const Color(0xFFD97706) : SevaCareColors.mint;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: SevaCareColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline, size: 22, color: SevaCareColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(request.patientName.isNotEmpty ? request.patientName : 'Patient',
                              style: AppTextStyles.cardTitle(SevaCareColors.text)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(pending ? 'Pending' : 'Confirmed',
                              style: AppTextStyles.badgeText(statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${request.specialty.isNotEmpty ? '${request.specialty} · ' : ''}'
                      '${request.patientAge > 0 ? 'Age ${request.patientAge}' : 'Age not provided'}',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoLine(icon: Icons.phone_outlined, text: request.patientMobile),
          if (request.preferredDate.isNotEmpty)
            _InfoLine(icon: Icons.event_outlined, text: 'Preferred: ${request.preferredDate}'),
          if (request.symptoms.isNotEmpty)
            _InfoLine(icon: Icons.notes_outlined, text: request.symptoms),
          if (!pending && (request.assignedSlot?.isNotEmpty ?? false))
            _InfoLine(icon: Icons.schedule_outlined, text: 'Assigned: ${request.assignedSlot}'),
          if (pending) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Confirm & Assign Slot',
              icon: Icons.check_circle_outline,
              fullWidth: true,
              onPressed: onConfirm,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: SevaCareColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodyText(SevaCareColors.text))),
        ],
      ),
    );
  }
}

// ── Confirm dialog ──────────────────────────────────────────────────────────────

class _ConfirmResult {
  final String bookingType; // TOKEN or SLOT
  final String? slot; // "yyyy-MM-dd HH:mm" — set when bookingType is SLOT
  final String? tokenSession; // MORNING/EVENING — set when bookingType is TOKEN
  final String? notes;
  const _ConfirmResult({required this.bookingType, this.slot, this.tokenSession, this.notes});
}

class _ConfirmDialog extends ConsumerStatefulWidget {
  final AppointmentRequest request;
  const _ConfirmDialog({required this.request});

  @override
  ConsumerState<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends ConsumerState<_ConfirmDialog> {
  String _bookingType = 'TOKEN';
  String _tokenSession = 'MORNING';
  TimeOfDay? _pickedTime;
  final _notesCtrl = TextEditingController();
  String? _err;
  int? _tokenPreviewNumber;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    _loadTokenPreview();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTokenPreview() async {
    setState(() {
      _loadingPreview = true;
      _tokenPreviewNumber = null;
    });
    try {
      final auth = ref.read(authProvider);
      final preview = await ref.read(repositoryProvider).getTokenPreview(
            auth.tenantPublicId ?? '',
            widget.request.doctorPublicId,
            widget.request.preferredDate,
            _tokenSession,
            auth.token ?? '',
          );
      if (mounted) {
        setState(() {
          _tokenPreviewNumber = preview.nextTokenNumber;
          _loadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickedTime ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Select appointment time',
    );
    if (picked != null && mounted) {
      setState(() {
        _pickedTime = picked;
        _err = null;
      });
    }
  }

  void _submit() {
    if (_bookingType == 'TOKEN') {
      Navigator.of(context).pop(_ConfirmResult(
        bookingType: 'TOKEN',
        tokenSession: _tokenSession,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ));
      return;
    }

    if (_pickedTime == null) {
      setState(() => _err = 'Please pick a time for this appointment.');
      return;
    }
    final hh = _pickedTime!.hour.toString().padLeft(2, '0');
    final mm = _pickedTime!.minute.toString().padLeft(2, '0');
    Navigator.of(context).pop(_ConfirmResult(
      bookingType: 'SLOT',
      slot: '${widget.request.preferredDate} $hh:$mm',
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Confirm ${widget.request.patientName}', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book this appointment for ${widget.request.preferredDate}. The patient will be contacted on ${widget.request.patientMobile}.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text('Booking Type', style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 6),
            SegmentedControl<String>(
              items: const [
                SegmentItem(value: 'TOKEN', label: 'Token'),
                SegmentItem(value: 'SLOT', label: 'Fixed Time'),
              ],
              selected: _bookingType,
              onChanged: (v) => setState(() {
                _bookingType = v;
                _err = null;
              }),
            ),
            const SizedBox(height: 14),
            if (_bookingType == 'TOKEN') ...[
              Text('Session', style: AppTextStyles.label(SevaCareColors.textMuted)),
              const SizedBox(height: 6),
              SegmentedControl<String>(
                items: const [
                  SegmentItem(value: 'MORNING', label: 'Morning'),
                  SegmentItem(value: 'EVENING', label: 'Evening'),
                ],
                selected: _tokenSession,
                onChanged: (v) {
                  setState(() => _tokenSession = v);
                  _loadTokenPreview();
                },
              ),
              const SizedBox(height: 10),
              Text(
                _loadingPreview
                    ? 'Checking next token…'
                    : _tokenPreviewNumber != null
                        ? 'Next token: #$_tokenPreviewNumber'
                        : '',
                style: AppTextStyles.label(SevaCareColors.primary),
              ),
            ] else ...[
              Text('Time', style: AppTextStyles.label(SevaCareColors.textMuted)),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _pickTime,
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(_pickedTime == null ? 'Pick a time' : _pickedTime!.format(context)),
              ),
            ],
            const SizedBox(height: 14),
            AppFormField(
              label: 'Notes (optional)',
              controller: _notesCtrl,
              placeholder: 'Any note for the patient…',
              maxLines: 2,
            ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Text(_err!, style: AppTextStyles.label(SevaCareColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

// ── Empty / Error states ────────────────────────────────────────────────────────

class _EmptyBox extends StatelessWidget {
  const _EmptyBox();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Icon(Icons.qr_code_scanner_outlined, size: 48, color: SevaCareColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text('No booking requests yet', style: AppTextStyles.sectionTitle(SevaCareColors.textMuted)),
          const SizedBox(height: 6),
          Text(
            'When a patient books via your hospital QR code or the chatbot, their request appears here with its auto-assigned token.',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const SizedBox(height: 12),
          const Icon(Icons.error_outline, size: 32, color: SevaCareColors.danger),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.bodyText(SevaCareColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Retry', icon: Icons.refresh, onPressed: onRetry),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
