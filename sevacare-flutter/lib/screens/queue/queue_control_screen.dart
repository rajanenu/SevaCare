import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snack.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/confirm_dialog.dart';

/// Interactive live queue control, shared by doctors and front-desk staff.
///
/// Unlike [QueueBoardScreen] (the read-only waiting-room TV display), this lets
/// whoever is driving the queue advance it in real time:
///   • **Done** completes the current token, so "Now Serving" moves to the next.
///   • **No-show** cancels a token that didn't turn up and skips past it.
///
/// It reuses the existing per-(doctor,date,session) unified token queue and the
/// existing complete / cancel endpoints, so both roles see the same live state.
class QueueControlScreen extends ConsumerStatefulWidget {
  /// Doctor whose queue is being managed. For a doctor this is their own id;
  /// staff pass the doctor they've selected on the dashboard.
  final String doctorPublicId;
  final String doctorName;

  const QueueControlScreen({
    super.key,
    required this.doctorPublicId,
    required this.doctorName,
  });

  @override
  ConsumerState<QueueControlScreen> createState() => _QueueControlScreenState();
}

class _QueueControlScreenState extends ConsumerState<QueueControlScreen> {
  DoctorQueueDayView? _queueView;
  bool _loading = true;
  String? _error;
  String? _busyAppointmentId; // guards double-taps during an action
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final hospital = ref.read(hospitalProvider);
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final view = await repo.getDoctorQueue(
        hospital.tenantPublicId,
        widget.doctorPublicId,
        AppDateUtils.offsetDay(0),
        auth.token ?? '',
      );
      if (mounted) {
        setState(() {
          _queueView = view;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (!silent) _error = 'Could not load the queue.';
        });
      }
    }
  }

  /// Pending, token-bearing appointments grouped by session and sorted by token.
  Map<String, List<DoctorQueueFacetView>> get _pendingBySession {
    final facets = (_queueView?.facets ?? [])
        .where((f) => f.tokenNumber != null)
        .toList();
    final bySession = <String, List<DoctorQueueFacetView>>{};
    for (final f in facets) {
      final s = f.status.toLowerCase();
      if (s == 'completed' || s == 'cancelled') continue;
      bySession.putIfAbsent(f.tokenSession ?? 'MORNING', () => []).add(f);
    }
    for (final list in bySession.values) {
      list.sort((a, b) => (a.tokenNumber ?? 0).compareTo(b.tokenNumber ?? 0));
    }
    return bySession;
  }

  int _completedCount(String session) => (_queueView?.facets ?? [])
      .where((f) =>
          (f.tokenSession ?? 'MORNING') == session &&
          f.status.toLowerCase() == 'completed')
      .length;

  Future<void> _markDone(DoctorQueueFacetView f) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Mark token #${f.tokenNumber} done?',
      message:
          '${f.patientName} will be marked completed and the queue moves to the next token.',
      confirmLabel: 'Mark Done',
      isDanger: false,
    );
    if (!ok) return;
    await _runAction(
      f,
      () async {
        final hospital = ref.read(hospitalProvider);
        final auth = ref.read(authProvider);
        await ref.read(repositoryProvider).completeConsultation(
              hospital.tenantPublicId,
              widget.doctorPublicId,
              f.appointmentPublicId,
              auth.token ?? '',
            );
      },
      successMessage: 'Token #${f.tokenNumber} completed.',
    );
  }

  Future<void> _markNoShow(DoctorQueueFacetView f) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Mark token #${f.tokenNumber} no-show?',
      message:
          '${f.patientName} will be removed from today\'s queue. They can be re-booked if they arrive later.',
      confirmLabel: 'No-show',
    );
    if (!ok) return;
    await _runAction(
      f,
      () async {
        final hospital = ref.read(hospitalProvider);
        final auth = ref.read(authProvider);
        await ref.read(repositoryProvider).cancelAppointment(
              hospital.tenantPublicId,
              f.patientPublicId,
              f.appointmentPublicId,
              auth.token ?? '',
              reason: 'No-show',
            );
      },
      successMessage: 'Token #${f.tokenNumber} marked no-show.',
    );
  }

  Future<void> _runAction(
    DoctorQueueFacetView f,
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    setState(() => _busyAppointmentId = f.appointmentPublicId);
    try {
      await action();
      await _load(silent: true);
      _toast(successMessage);
    } catch (_) {
      _toast('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busyAppointmentId = null);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppSnack.error(context, message);
    } else {
      AppSnack.success(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _pendingBySession;

    return Scaffold(
      backgroundColor: SevaCareColors.background,
      appBar: AppBar(
        title: const Text('Live Queue Control'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _load(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Text(
                        widget.doctorName,
                        style: AppTextStyles.sectionTitle(SevaCareColors.text),
                      ),
                      Text(
                        AppDateUtils.weekdayDateLabel(AppDateUtils.todayApi()),
                        style: AppTextStyles.label(SevaCareColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      if (sessions.isEmpty)
                        const _EmptyState()
                      else
                        for (final session in _orderedSessions(sessions.keys))
                          _SessionSection(
                            session: session,
                            pending: sessions[session]!,
                            completed: _completedCount(session),
                            busyAppointmentId: _busyAppointmentId,
                            onDone: _markDone,
                            onNoShow: _markNoShow,
                          ),
                    ],
                  ),
                ),
    );
  }

  List<String> _orderedSessions(Iterable<String> keys) {
    final list = keys.toList()
      ..sort((a, b) => a == b ? 0 : (a == 'MORNING' ? -1 : 1));
    return list;
  }
}

class _SessionSection extends StatelessWidget {
  final String session;
  final List<DoctorQueueFacetView> pending;
  final int completed;
  final String? busyAppointmentId;
  final Future<void> Function(DoctorQueueFacetView) onDone;
  final Future<void> Function(DoctorQueueFacetView) onNoShow;

  const _SessionSection({
    required this.session,
    required this.pending,
    required this.completed,
    required this.busyAppointmentId,
    required this.onDone,
    required this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    final nowServing = pending.isNotEmpty ? pending.first : null;
    final waiting = pending.length > 1 ? pending.sublist(1) : <DoctorQueueFacetView>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              session == 'EVENING' ? 'Evening session' : 'Morning session',
              style: AppTextStyles.labelCaps(SevaCareColors.primary),
            ),
            const Spacer(),
            Text(
              '${pending.length} waiting · $completed done',
              style: AppTextStyles.label(SevaCareColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (nowServing != null)
          _NowServingCard(
            facet: nowServing,
            busy: busyAppointmentId == nowServing.appointmentPublicId,
            onDone: () => onDone(nowServing),
            onNoShow: () => onNoShow(nowServing),
          ),
        const SizedBox(height: 10),
        for (final f in waiting)
          _WaitingRow(
            facet: f,
            busy: busyAppointmentId == f.appointmentPublicId,
            onDone: () => onDone(f),
            onNoShow: () => onNoShow(f),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _NowServingCard extends StatelessWidget {
  final DoctorQueueFacetView facet;
  final bool busy;
  final VoidCallback onDone;
  final VoidCallback onNoShow;

  const _NowServingCard({
    required this.facet,
    required this.busy,
    required this.onDone,
    required this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: SevaCareColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOW SERVING',
            style: AppTextStyles.label(Colors.white.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '#${facet.tokenNumber}',
                style: AppTextStyles.display(
                  size: 48,
                  weight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      facet.patientName,
                      style: AppTextStyles.sectionTitle(Colors.white),
                    ),
                    if (facet.isQrBooking)
                      Text(
                        'Walk-in (QR)',
                        style: AppTextStyles.label(
                          Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Mark Done',
                  icon: Icons.check_circle_rounded,
                  filled: true,
                  busy: busy,
                  onPressed: onDone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'No-show',
                  icon: Icons.person_off_rounded,
                  filled: false,
                  busy: busy,
                  onPressed: onNoShow,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  final DoctorQueueFacetView facet;
  final bool busy;
  final VoidCallback onDone;
  final VoidCallback onNoShow;

  const _WaitingRow({
    required this.facet,
    required this.busy,
    required this.onDone,
    required this.onNoShow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SevaCareColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${facet.tokenNumber}',
              style: AppTextStyles.sectionTitle(SevaCareColors.primary),
            ),
          ),
          Expanded(
            child: Text(
              facet.patientName,
              style: AppTextStyles.bodyText(SevaCareColors.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'Mark done',
              icon: const Icon(Icons.check_circle_outline_rounded),
              color: SevaCareColors.primary,
              onPressed: onDone,
            ),
            IconButton(
              tooltip: 'No-show',
              icon: const Icon(Icons.person_off_outlined),
              color: SevaCareColors.textMuted,
              onPressed: onNoShow,
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = filled ? SevaCareColors.primary : Colors.white;
    final bg = filled ? Colors.white : Colors.white.withValues(alpha: 0.16);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: busy
              ? SizedBox(
                  height: 18,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Text(label, style: AppTextStyles.buttonLabel(fg)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Icon(Icons.event_available_rounded,
              size: 56, color: SevaCareColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No one waiting in the queue',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 40, color: SevaCareColors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
