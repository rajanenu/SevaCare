import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class MedicalHistoryScreen extends ConsumerStatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  ConsumerState<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends ConsumerState<MedicalHistoryScreen> {
  MedicalHistoryView? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final data = await repo.getPatientMedicalHistory(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
      );
      if (mounted) setState(() => _history = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _rxLabel(String id) {
    final clean = id.replaceAll('-', '').toUpperCase();
    final suffix = clean.length > 8 ? clean.substring(clean.length - 8) : clean;
    return 'RX-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final history = _history;

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: UserRole.patient,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back button
          BackBtn(onPressed: () => context.canPop() ? context.pop() : context.go('/patient')),
          const SizedBox(height: 16),

          const PageHeader(title: 'Medical History'),
          const SizedBox(height: 8),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: ShimmerList(count: 4, cardHeight: 96),
            )
          else if (_error != null)
            SizedBox(
              height: 400,
              child: AppErrorState(message: _error!, onRetry: _load),
            )
          else if (history == null)
            const SizedBox(
              height: 400,
              child: AppEmptyState(
                icon: Icons.folder_open_rounded,
                title: 'No medical history yet',
                message: 'Your visit records and prescriptions will appear here.',
              ),
            )
          else ...[
            // ── Follow-up banner
            if (history.followUpRequired) ...[
              AccentCard(
                variant: MetricVariant.peach,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: context.colors.peachForeground, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Follow-up Required',
                            style: AppTextStyles.cardTitle(context.colors.peachForeground),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your doctor has recommended a follow-up visit.',
                            style: AppTextStyles.bodyText(context.colors.peachForeground),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Last checkup
            if (history.lastCheckup != null && history.lastCheckup!.isNotEmpty) ...[
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: context.colors.mintSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.event_available_outlined,
                          color: context.colors.mintForeground, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Last Checkup',
                            style: AppTextStyles.label(context.colors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          AppDateUtils.formatDisplay(history.lastCheckup),
                          style: AppTextStyles.cardTitle(context.colors.text),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // ── Past Appointments
            Text('Past Appointments',
                style: AppTextStyles.sectionTitle(context.colors.text)),
            const SizedBox(height: 12),
            if (history.appointments.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        color: context.colors.textMuted, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      'No past appointments',
                      style: AppTextStyles.bodyText(context.colors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.appointments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final appt = history.appointments[index];
                  return AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: context.colors.primarySoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.person_outline,
                              color: context.colors.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appt.doctorName.isNotEmpty
                                    ? 'Dr. ${appt.doctorName}'
                                    : 'Doctor',
                                style: AppTextStyles.cardTitle(context.colors.text),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                AppDateUtils.formatSlot(appt.slot),
                                style: AppTextStyles.label(context.colors.textMuted),
                              ),
                              if (appt.note != null && appt.note!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  appt.note!,
                                  style: AppTextStyles.bodyText(context.colors.textMuted),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: appt.status),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // ── Prescriptions
            Text('Prescriptions', style: AppTextStyles.sectionTitle(context.colors.text)),
            const SizedBox(height: 12),
            if (history.prescriptions.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    Icon(Icons.medication_outlined,
                        color: context.colors.textMuted, size: 32),
                    const SizedBox(height: 10),
                    Text(
                      'No prescriptions found',
                      style: AppTextStyles.bodyText(context.colors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: history.prescriptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rx = history.prescriptions[index];
                  return AppCard(
                    onTap: () =>
                        context.push('/patient/prescriptions/${rx.prescriptionPublicId}'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _rxLabel(rx.prescriptionPublicId),
                                    style: AppTextStyles.cardTitle(context.colors.text),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dr. ${rx.doctorName}',
                                    style: AppTextStyles.label(context.colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: rx.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _HistoryChip(
                              label:
                                  '${rx.medicines.length} medicine${rx.medicines.length == 1 ? '' : 's'}',
                              icon: Icons.medication_outlined,
                              bgColor: context.colors.primarySoft,
                              fgColor: context.colors.primary,
                            ),
                            const SizedBox(width: 8),
                            _HistoryChip(
                              label: AppDateUtils.formatDisplay(rx.issuedOn),
                              icon: Icons.calendar_today_outlined,
                              bgColor: context.colors.surfaceMuted,
                              fgColor: context.colors.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

// ── Chip helper ───────────────────────────────────────────────────────────────

class _HistoryChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;

  const _HistoryChip({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.chipLabel(fgColor)),
        ],
      ),
    );
  }
}
