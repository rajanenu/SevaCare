import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class DoctorPrescriptionsScreen extends ConsumerStatefulWidget {
  const DoctorPrescriptionsScreen({super.key});

  @override
  ConsumerState<DoctorPrescriptionsScreen> createState() =>
      _DoctorPrescriptionsScreenState();
}

class _DoctorPrescriptionsScreenState
    extends ConsumerState<DoctorPrescriptionsScreen> {
  List<PrescriptionDetailView>? _prescriptions;
  bool _loading = true;
  String? _error;

  static const _doctorBottomNav = [
    BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/doctor'),
    BottomNavItem(label: 'Consult', icon: Icons.healing, route: '/doctor/consult'),
    BottomNavItem(label: 'Rx', icon: Icons.medication_outlined, route: '/doctor/prescriptions'),
    BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/doctor/profile'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = ref.read(authProvider);
      final data = await ref.read(repositoryProvider).getDoctorPrescriptions(
        auth.tenantPublicId ?? '',
        auth.subjectPublicId ?? '',
        auth.token ?? '',
      );
      setState(() { _prescriptions = data; _loading = false; });
    } catch (e) {
      setState(() { _error = extractErrorMessage(e, fallback: 'Failed to load prescriptions.'); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hospitalName = ref.watch(hospitalProvider).hospitalName;
    final list = _prescriptions ?? [];

    return AppShell(
      hospitalName: hospitalName,
      role: UserRole.doctor,
      bottomNavItems: _doctorBottomNav,
      currentNavIndex: 2,
      onNavTap: (i) => context.go(_doctorBottomNav[i].route),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BackBtn(onPressed: () => context.go('/doctor')),
          const SizedBox(height: 8),
          PageHeader(
            title: 'Prescriptions Issued',
            subtitle: 'Total: ${list.length}',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const ShimmerList(count: 4, cardHeight: 88)
          else if (_error != null)
            _ErrorView(error: _error!, onRetry: _load)
          else if (list.isEmpty)
            _EmptyView()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, idx) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _PrescriptionCard(rx: list[i]),
            ),
        ],
      ),
    );
  }
}

class _PrescriptionCard extends StatelessWidget {
  final PrescriptionDetailView rx;
  const _PrescriptionCard({required this.rx});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rx.prescriptionPublicId,
                  style: AppTextStyles.cardTitle(context.colors.text),
                ),
              ),
              StatusBadge(status: rx.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dr. ${rx.doctorName}',
            style: AppTextStyles.bodyText(context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Chip(
                label: '${rx.medicines.length} medicine${rx.medicines.length == 1 ? '' : 's'}',
                bg: context.colors.mintSoft,
                fg: context.colors.mintForeground,
              ),
              const SizedBox(width: 8),
              _Chip(
                label: AppDateUtils.formatDisplay(rx.issuedOn),
                bg: context.colors.primarySoft,
                fg: context.colors.primary,
              ),
            ],
          ),
          if (rx.medicines.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionDivider(),
            const SizedBox(height: 8),
            ...rx.medicines.take(3).map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: context.colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${m.name}  ${m.strength}  ${m.frequency}',
                        style: AppTextStyles.bodyText(context.colors.text),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (rx.medicines.length > 3)
              Text(
                '+${rx.medicines.length - 3} more',
                style: AppTextStyles.badgeText(context.colors.textMuted),
              ),
          ] else if (rx.notes != null && rx.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            const SectionDivider(),
            const SizedBox(height: 8),
            Text(
              rx.notes!,
              style: AppTextStyles.bodyText(context.colors.text),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextStyles.chipLabel(fg)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(Icons.medication_outlined, size: 48, color: context.colors.border),
            const SizedBox(height: 12),
            Text('No prescriptions issued yet', style: AppTextStyles.bodyText(context.colors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text('Failed to load', style: AppTextStyles.bodyText(context.colors.danger)),
          const SizedBox(height: 12),
          SecondaryButton(label: 'Retry', onPressed: onRetry),
        ],
      ),
    );
  }
}
