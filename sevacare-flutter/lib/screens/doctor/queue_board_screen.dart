import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';

/// Live token/queue position for a single session (Morning or Evening).
class SessionQueueState {
  final String session;
  final int? nowServing;
  final int? upNext;
  final int waiting;
  final int completed;
  final int total;

  /// Projected call time ("HH:mm") of the last waiting token — the server's
  /// measured-pace estimate of when this session's queue clears.
  final String? lastCallEta;

  const SessionQueueState({
    required this.session,
    required this.nowServing,
    required this.upNext,
    required this.waiting,
    required this.completed,
    required this.total,
    this.lastCallEta,
  });
}

/// Derives "Now Serving" / "Up Next" token positions from a doctor's queue
/// for today, grouped by token session (Morning / Evening). Facets are
/// already sorted by token number by the backend, but we sort defensively.
List<SessionQueueState> computeQueueStates(List<DoctorQueueFacetView> facets) {
  // Unified queue: slot and token bookings share one sequence, so the board
  // shows every appointment that carries a token, regardless of how it was booked.
  final tokenFacets = facets.where((f) => f.tokenNumber != null).toList();
  final bySession = <String, List<DoctorQueueFacetView>>{};
  for (final f in tokenFacets) {
    bySession.putIfAbsent(f.tokenSession ?? 'MORNING', () => []).add(f);
  }

  final result = <SessionQueueState>[];
  for (final entry in bySession.entries) {
    final list = entry.value
      ..sort((a, b) => (a.tokenNumber ?? 0).compareTo(b.tokenNumber ?? 0));
    final pending = list.where((f) {
      final s = f.status.toLowerCase();
      return s != 'completed' && s != 'cancelled';
    }).toList();
    final completedCount = list
        .where((f) => f.status.toLowerCase() == 'completed')
        .length;

    result.add(
      SessionQueueState(
        session: entry.key,
        nowServing: pending.isNotEmpty ? pending.first.tokenNumber : null,
        upNext: pending.length > 1 ? pending[1].tokenNumber : null,
        waiting: pending.length,
        completed: completedCount,
        total: list.length,
        lastCallEta: pending.isNotEmpty ? pending.last.estimatedCallAt : null,
      ),
    );
  }

  // Morning before Evening, stable order otherwise.
  result.sort(
    (a, b) => a.session == b.session ? 0 : (a.session == 'MORNING' ? -1 : 1),
  );
  return result;
}

/// Fullscreen, high-contrast "Now Serving" display designed to run on a
/// waiting-room tablet or TV — auto-refreshes so reception never has to
/// touch it during the day.
class QueueBoardScreen extends ConsumerStatefulWidget {
  const QueueBoardScreen({super.key});

  @override
  ConsumerState<QueueBoardScreen> createState() => _QueueBoardScreenState();
}

class _QueueBoardScreenState extends ConsumerState<QueueBoardScreen> {
  DoctorQueueDayView? _queueView;
  bool _loading = true;
  String? _error;
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
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final view = await repo.getDoctorQueue(
        hospital.tenantPublicId,
        auth.subjectPublicId ?? '',
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (!silent) _error = 'Could not load the queue.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);

    return Scaffold(
      backgroundColor: context.colors.primaryStrong,
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.colors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              width: double.infinity,
              height: double.infinity,
            ),
            Positioned(
              top: 8,
              left: 8,
              child: _CloseButton(
                onTap: () => Navigator.of(context).maybePop(),
              ),
            ),
            Center(
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _error != null
                  ? _BoardError(message: _error!, onRetry: _load)
                  : _BoardContent(
                      hospitalName: hospital.hospitalName.isNotEmpty
                          ? hospital.hospitalName
                          : 'SevaCare',
                      states: computeQueueStates(_queueView?.facets ?? []),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close queue board',
      button: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _BoardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_rounded, size: 40, color: Colors.white70),
        const SizedBox(height: 12),
        Text(message, style: AppTextStyles.bodyText(Colors.white70)),
        const SizedBox(height: 16),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry', style: AppTextStyles.buttonLabel(Colors.white)),
        ),
      ],
    );
  }
}

class _BoardContent extends StatelessWidget {
  final String hospitalName;
  final List<SessionQueueState> states;
  const _BoardContent({required this.hospitalName, required this.states});

  @override
  Widget build(BuildContext context) {
    if (states.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_available_rounded,
            size: 56,
            color: Colors.white70,
          ),
          const SizedBox(height: 16),
          Text(
            'No appointments in the queue yet',
            style: AppTextStyles.pageTitle(Colors.white),
          ),
        ],
      );
    }

    // Capped so the board stays readable instead of stretching edge-to-edge
    // on a wide desktop/TV display — session cards use `width: double.infinity`.
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hospitalName,
                style: AppTextStyles.label(
                  Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'LIVE TOKEN BOARD',
                style: AppTextStyles.labelCaps(
                  Colors.white,
                ).copyWith(letterSpacing: 2),
              ),
              const SizedBox(height: 6),
              Text(
                AppDateUtils.weekdayDateLabel(AppDateUtils.todayApi()),
                style: AppTextStyles.label(Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 24),
              for (final s in states) ...[
                _SessionBoard(state: s),
                const SizedBox(height: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionBoard extends StatelessWidget {
  final SessionQueueState state;
  const _SessionBoard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            state.session == 'EVENING' ? 'EVENING SESSION' : 'MORNING SESSION',
            style: AppTextStyles.labelCaps(
              Colors.white70,
            ).copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          Text(
            'NOW SERVING',
            style: AppTextStyles.label(Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            key: ValueKey(state.nowServing),
            tween: Tween(begin: 0.85, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Text(
              state.nowServing != null ? '#${state.nowServing}' : '—',
              style: AppTextStyles.display(
                size: 96,
                weight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _MiniStat(
                label: 'Up Next',
                value: state.upNext != null ? '#${state.upNext}' : '—',
              ),
              const SizedBox(width: 16),
              _MiniStat(label: 'Waiting', value: '${state.waiting}'),
              const SizedBox(width: 16),
              _MiniStat(label: 'Completed', value: '${state.completed}'),
            ],
          ),
          if (state.lastCallEta != null) ...[
            const SizedBox(height: 14),
            Text(
              'Last token expected around ${state.lastCallEta}',
              style: AppTextStyles.label(Colors.white.withValues(alpha: 0.75)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.display(
              size: 22,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.label(Colors.white.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}
