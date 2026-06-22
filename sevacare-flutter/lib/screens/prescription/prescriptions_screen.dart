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

class PrescriptionsScreen extends ConsumerStatefulWidget {
  const PrescriptionsScreen({super.key});

  @override
  ConsumerState<PrescriptionsScreen> createState() => _PrescriptionsScreenState();
}

class _PrescriptionsScreenState extends ConsumerState<PrescriptionsScreen> {
  PrescriptionCollectionView? _collection;
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
      final data = await repo.getPatientPrescriptions(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
      );
      if (mounted) setState(() => _collection = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _rxLabel(String prescriptionPublicId) {
    // Format as RX-XXXX using last 8 chars of the id, uppercased
    final id = prescriptionPublicId.replaceAll('-', '').toUpperCase();
    final suffix = id.length > 8 ? id.substring(id.length - 8) : id;
    return 'RX-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final prescriptions = _collection?.prescriptions ?? [];

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: UserRole.patient,
      bottomNavItems: const [
        BottomNavItem(label: 'Dashboard', icon: Icons.grid_view_rounded, route: '/patient'),
        BottomNavItem(label: 'Doctors', icon: Icons.people_outline, route: '/patient/doctors'),
        BottomNavItem(
            label: 'Appointments',
            icon: Icons.calendar_today_outlined,
            route: '/patient/appointments'),
        BottomNavItem(label: 'Rx', icon: Icons.medication_outlined, route: '/patient/prescriptions'),
        BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/patient/profile'),
      ],
      currentNavIndex: 3,
      onNavTap: (i) {
        const routes = [
          '/patient',
          '/patient/doctors',
          '/patient/appointments',
          '/patient/prescriptions',
          '/patient/profile',
        ];
        if (i < routes.length) context.go(routes[i]);
      },
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'My Prescriptions',
              subtitle: _loading ? null : 'Total: ${prescriptions.length}',
            ),
            const SizedBox(height: 8),
            if (_loading)
              const SizedBox(
                height: 400,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: SevaCareColors.danger, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                      const SizedBox(height: 16),
                      PrimaryButton(label: 'Retry', onPressed: _load),
                    ],
                  ),
                ),
              )
            else if (prescriptions.isEmpty)
              SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medication_outlined,
                          color: SevaCareColors.textMuted, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'No prescriptions found',
                        style: AppTextStyles.sectionTitle(SevaCareColors.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your prescriptions will appear here once issued by a doctor.',
                        style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: prescriptions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rx = prescriptions[index];
                  return AppCard(
                    onTap: () => context.push('/patient/prescriptions/${rx.prescriptionPublicId}'),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: ID + doctor + status
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _rxLabel(rx.prescriptionPublicId),
                                    style: AppTextStyles.cardTitle(SevaCareColors.text),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Dr. ${rx.doctorName}',
                                    style: AppTextStyles.label(SevaCareColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            StatusBadge(status: rx.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Bottom chips: medicine count + date
                        Row(
                          children: [
                            _Chip(
                              label: '${rx.medicines.length} medicine${rx.medicines.length == 1 ? '' : 's'}',
                              icon: Icons.medication_outlined,
                              bgColor: SevaCareColors.primarySoft,
                              fgColor: SevaCareColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _Chip(
                              label: AppDateUtils.formatDisplay(rx.issuedOn),
                              icon: Icons.calendar_today_outlined,
                              bgColor: SevaCareColors.surfaceMuted,
                              fgColor: SevaCareColors.textMuted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Small chip helper ─────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color fgColor;

  const _Chip({
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
