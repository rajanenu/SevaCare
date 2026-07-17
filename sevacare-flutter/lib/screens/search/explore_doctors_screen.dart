import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/responsive/breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/doctor_name.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// Doctor profile cards are portrait (photo + name + specialty) — as columns
/// increase on wider screens each card gets narrower, so the aspect ratio is
/// widened alongside the column count to avoid overly elongated cards.
SliverGridDelegateWithFixedCrossAxisCount _doctorGridDelegate(
  BuildContext context,
) {
  final columns = columnsForWidth(
    MediaQuery.sizeOf(context).width,
    mobileCols: 2,
    tabletCols: 3,
    desktopCols: 4,
  );
  final aspectRatio = switch (columns) {
    2 => 0.58,
    3 => 0.72,
    _ => 0.85,
  };
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    mainAxisSpacing: 12,
    crossAxisSpacing: 12,
    childAspectRatio: aspectRatio,
  );
}

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
  ConsumerState<ExploreDoctorsScreen> createState() =>
      _ExploreDoctorsScreenState();
}

class _ExploreDoctorsScreenState extends ConsumerState<ExploreDoctorsScreen> {
  late Future<List<DoctorSummary>> _doctorsFuture;

  @override
  void initState() {
    super.initState();
    _doctorsFuture = ref
        .read(repositoryProvider)
        .listPublicDoctors(widget.tenantId);
  }

  void _retry() {
    setState(
      () => _doctorsFuture = ref
          .read(repositoryProvider)
          .listPublicDoctors(widget.tenantId),
    );
  }

  void _loginToBook() {
    // Select this hospital so the login screen is scoped to it, then go to
    // login (previously this incorrectly bounced back to Search Hospitals).
    ref
        .read(hospitalProvider.notifier)
        .selectHospital(
          TenantSummary(
            tenantPublicId: widget.tenantId,
            hospitalName: widget.hospitalName,
            city: '',
            specialty: '',
            themeKey: 'premium',
          ),
        );
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      hospitalName: widget.hospitalName.isNotEmpty
          ? widget.hospitalName
          : 'SevaCare',
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
                gridDelegate: _doctorGridDelegate(context),
                itemBuilder: (context, index) => StaggeredItem(
                  index: index,
                  child: _DoctorProfileCard(doctor: doctors[index]),
                ),
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
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Photo — 60% of the card
            Expanded(
              flex: 6,
              child: DoctorPhoto(
                doctorId: doctor.doctorPublicId,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // ── Details — 40% of the card
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Dr. ${stripDoctorPrefix(doctor.name)}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle(context.colors.text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      doctor.experienceYears != null
                          ? '${doctor.specialty} · ${doctor.experienceYears}y Exp'
                          : doctor.specialty,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(context.colors.textMuted),
                    ),
                    if (doctor.qualification != null &&
                        doctor.qualification!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        doctor.qualification!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label(context.colors.textMuted),
                      ),
                    ],
                    if (doctor.averageRating != null) ...[
                      const SizedBox(height: 3),
                      RatingStars(
                        averageRating: doctor.averageRating,
                        reviewCount: doctor.reviewCount,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Loading / Error / Empty states ──────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF7FAFC),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: _doctorGridDelegate(context),
        itemBuilder: (context, index) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
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
          Icon(
            Icons.error_outline,
            size: 32,
            color: context.colors.danger,
          ),
          const SizedBox(height: 12),
          Text(
            'Could not load doctors',
            style: AppTextStyles.cardTitle(context.colors.danger),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: onRetry,
          ),
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
          Icon(
            Icons.medical_services_outlined,
            size: 32,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            'No doctors registered yet',
            style: AppTextStyles.cardTitle(context.colors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'This hospital hasn\'t added any doctors yet. Please check back soon.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyText(context.colors.textMuted),
          ),
        ],
      ),
    );
  }
}
