import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/data_cache.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _doctorListProvider =
    FutureProvider.autoDispose<List<DoctorRecord>>((ref) async {
  final auth = ref.read(authProvider);
  final repo = ref.read(repositoryProvider);
  final tenantId = auth.tenantPublicId ?? '';
  final token = auth.token ?? '';

  // Try network first, fall back to cache on failure
  try {
    final docs = await repo.listDoctorRecords(tenantId, token);
    await DataCache.saveDoctors(docs); // keep cache warm
    return docs;
  } catch (_) {
    return DataCache.loadDoctors();
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _filterSpecialty = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(_doctorListProvider);
    final role = ref.watch(authProvider).role;

    return AppShell(
      hospitalName: ref.watch(hospitalProvider).hospitalName.isNotEmpty
          ? ref.watch(hospitalProvider).hospitalName
          : 'SevaCare',
      role: role,
      showBackButton: true,
      onBack: () => context.pop(),
      // Fixed-frame layout: header, search field and filter chips stay put;
      // only the results list scrolls/updates on filter or query changes.
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Search',
            subtitle: 'Find doctors by name, specialty, or availability',
          ),
          const SizedBox(height: 16),

          // ── Search field ───────────────────────────────────────────────────
          Semantics(
            label: 'Search doctors',
            textField: true,
            child: Container(
              decoration: BoxDecoration(
                color: SevaCareColors.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: SevaCareColors.border, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: SevaCareColors.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: AppTextStyles.inputText(SevaCareColors.text),
                decoration: InputDecoration(
                  hintText: 'Doctor name, specialty…',
                  hintStyle: AppTextStyles.inputText(SevaCareColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: SevaCareColors.primary, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? Semantics(
                          label: 'Clear search',
                          button: true,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              child: const Icon(Icons.close_rounded,
                                  color: SevaCareColors.textMuted, size: 18),
                            ),
                          ),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Results ────────────────────────────────────────────────────────
          Expanded(
            child: doctorsAsync.when(
            loading: () => const SingleChildScrollView(
              primary: false,
              physics: NeverScrollableScrollPhysics(),
              child: ShimmerList(count: 4, cardHeight: 80),
            ),
            error: (e, _) => SingleChildScrollView(
              primary: false,
              physics: const BouncingScrollPhysics(),
              child: AppCard(
                child: Text(extractErrorMessage(e),
                    style: AppTextStyles.bodyText(SevaCareColors.danger)),
              ),
            ),
            data: (docs) {
              // Specialty filter chips
              final specialties = ['All', ...{for (final d in docs) d.specialty}
                  .toList()..sort()];

              // Filter
              final results = docs.where((d) {
                final matchesQuery = _query.isEmpty ||
                    d.fullName.toLowerCase().contains(_query) ||
                    d.specialty.toLowerCase().contains(_query) ||
                    (d.aboutMe?.toLowerCase().contains(_query) ?? false);
                final matchesSpecialty = _filterSpecialty == 'All' ||
                    d.specialty == _filterSpecialty;
                return matchesQuery && matchesSpecialty;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Specialty chips
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: specialties.length,
                      separatorBuilder: (context, i) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final s = specialties[i];
                        final active = _filterSpecialty == s;
                        return Semantics(
                          label: 'Filter by $s',
                          button: true,
                          selected: active,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _filterSpecialty = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: active
                                    ? SevaCareColors.primary
                                    : SevaCareColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active
                                      ? SevaCareColors.primary
                                      : SevaCareColors.border,
                                ),
                              ),
                              child: Text(
                                s,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? Colors.white
                                      : SevaCareColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  Expanded(
                    child: results.isEmpty
                        ? SingleChildScrollView(
                            primary: false,
                            physics: const BouncingScrollPhysics(),
                            child: AppCard(
                              child: Column(
                                children: [
                                  const Icon(Icons.search_off_rounded,
                                      size: 40, color: SevaCareColors.textMuted),
                                  const SizedBox(height: 10),
                                  Text(
                                    _query.isEmpty
                                        ? 'No doctors found in this hospital.'
                                        : 'No results for "$_query"',
                                    style: AppTextStyles.bodyText(
                                        SevaCareColors.textMuted),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView(
                            primary: false,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              Text(
                                '${results.length} doctor${results.length == 1 ? '' : 's'} found',
                                style: AppTextStyles.label(SevaCareColors.textMuted),
                              ),
                              const SizedBox(height: 10),
                              ...results.map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _DoctorSearchCard(doctor: d, role: role),
                                  )),
                            ],
                          ),
                  ),
                ],
              );
            },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Doctor result card ─────────────────────────────────────────────────────────

class _DoctorSearchCard extends StatelessWidget {
  final DoctorRecord doctor;
  final UserRole? role;

  const _DoctorSearchCard({required this.doctor, required this.role});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Dr. ${doctor.fullName}, ${doctor.specialty}, fee ${doctor.fee}, ${doctor.active ? 'active' : 'inactive'}',
      button: role == UserRole.patient,
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: SevaCareColors.mintSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  doctor.fullName.isNotEmpty
                      ? doctor.fullName[0].toUpperCase()
                      : 'D',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SevaCareColors.mintForeground,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dr. ${doctor.fullName}',
                          style: AppTextStyles.cardTitle(SevaCareColors.text),
                        ),
                      ),
                      if (!doctor.active)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: SevaCareColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.pause_circle_outline_rounded,
                                  size: 10,
                                  color: SevaCareColors.textMuted),
                              SizedBox(width: 3),
                              Text('Inactive',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: SevaCareColors.textMuted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 12, color: SevaCareColors.primary),
                    const SizedBox(width: 4),
                    Text(doctor.specialty,
                        style: AppTextStyles.label(SevaCareColors.primary)),
                  ]),
                  if (doctor.availability.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.schedule_outlined,
                          size: 12, color: SevaCareColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(doctor.availability,
                            style: AppTextStyles.label(SevaCareColors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SevaCareColors.primarySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '₹${doctor.fee}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: SevaCareColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Book button for patients
                    if (role == UserRole.patient && doctor.active)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/book'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: SevaCareColors.buttonGradient,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today_outlined,
                                    size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text('Book',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    )),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
