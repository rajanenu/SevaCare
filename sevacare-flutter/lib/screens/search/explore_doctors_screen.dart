import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// Public, no-login doctor directory for a single hospital — reachable from
/// the "Explore Doctors" link on each hospital card in [HospitalSearchScreen].
class ExploreDoctorsScreen extends ConsumerStatefulWidget {
  final String tenantId;
  final String hospitalName;

  const ExploreDoctorsScreen({
    super.key,
    required this.tenantId,
    required this.hospitalName,
  });

  @override
  ConsumerState<ExploreDoctorsScreen> createState() => _ExploreDoctorsScreenState();
}

class _ExploreDoctorsScreenState extends ConsumerState<ExploreDoctorsScreen> {
  late Future<List<DoctorSummary>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = ref.read(repositoryProvider).listPublicDoctors(widget.tenantId);
  }

  void _retry() {
    setState(() => _doctorsFuture = ref.read(repositoryProvider).listPublicDoctors(widget.tenantId));
  }

  void _loginToBook() {
    context.go('/search');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      hospitalName: widget.hospitalName.isNotEmpty ? widget.hospitalName : 'SevaCare',
      showBackButton: true,
      onBack: () => context.go('/search'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(
            title: 'Our Doctors',
            subtitle: widget.hospitalName.isNotEmpty
                ? 'Meet the doctors at ${widget.hospitalName}'
                : 'Meet our doctors',
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<DoctorSummary>>(
            future: _doctorsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingState();
              }
              if (snapshot.hasError) {
                return _ErrorState(onRetry: _retry);
              }
              final doctors = snapshot.data ?? [];
              if (doctors.isEmpty) {
                return const _EmptyState();
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: doctors.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemBuilder: (context, index) => _DoctorProfileCard(doctor: doctors[index]),
              );
            },
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Login to Book an Appointment',
            icon: Icons.login,
            fullWidth: true,
            onPressed: _loginToBook,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Doctor Profile Card ─────────────────────────────────────────────────────────

class _DoctorProfileCard extends StatelessWidget {
  final DoctorSummary doctor;
  const _DoctorProfileCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final initials = doctor.name.isNotEmpty
        ? doctor.name.trim().split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join()
        : '?';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAvatar(
            initials: initials,
            size: 56,
            hue: AppAvatar.hueFromString(doctor.doctorPublicId),
          ),
          const SizedBox(height: 10),
          Text(
            'Dr. ${doctor.name}',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.cardTitle(SevaCareColors.text),
          ),
          const SizedBox(height: 2),
          Text(
            doctor.specialty,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
          if (doctor.qualification != null && doctor.qualification!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              doctor.qualification!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(SevaCareColors.textMuted),
            ),
          ],
          if (doctor.experienceYears != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: SevaCareColors.primarySoft,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              child: Text(
                '${doctor.experienceYears}y Exp',
                style: AppTextStyles.chipLabel(SevaCareColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Loading / Error / Empty states ──────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(SevaCareColors.primary),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 32, color: SevaCareColors.danger),
          const SizedBox(height: 12),
          Text('Could not load doctors', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Retry', icon: Icons.refresh, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medical_services_outlined, size: 32, color: SevaCareColors.textMuted),
          const SizedBox(height: 12),
          Text('No doctors listed yet', style: AppTextStyles.cardTitle(SevaCareColors.text)),
        ],
      ),
    );
  }
}
