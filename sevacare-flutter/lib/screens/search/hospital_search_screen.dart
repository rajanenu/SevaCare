import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class HospitalSearchScreen extends ConsumerStatefulWidget {
  const HospitalSearchScreen({super.key});

  @override
  ConsumerState<HospitalSearchScreen> createState() => _HospitalSearchScreenState();
}

class _HospitalSearchScreenState extends ConsumerState<HospitalSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late Future<List<TenantSummary>> _tenantsFuture;
  List<String> _recentIds = [];

  static const _prefsKey = 'recent_hospital_ids';
  static const _maxRecent = 3;

  @override
  void initState() {
    super.initState();
    _tenantsFuture = ref.read(repositoryProvider).listTenants();
    _searchController.addListener(() => setState(() => _query = _searchController.text));
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && mounted) {
      setState(() => _recentIds = (jsonDecode(raw) as List).cast<String>());
    }
  }

  Future<void> _saveRecent(String id) async {
    final updated = [id, ..._recentIds.where((e) => e != id)].take(_maxRecent).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(updated));
    if (mounted) setState(() => _recentIds = updated);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TenantSummary> _sortAndFilter(List<TenantSummary> tenants) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<TenantSummary>.from(tenants)
        : tenants.where((t) {
            return t.hospitalName.toLowerCase().contains(q) ||
                t.city.toLowerCase().contains(q) ||
                t.specialty.toLowerCase().contains(q);
          }).toList();

    // Move recently visited to the top (preserving recency order)
    if (_recentIds.isNotEmpty) {
      filtered.sort((a, b) {
        final ai = _recentIds.indexOf(a.tenantPublicId);
        final bi = _recentIds.indexOf(b.tenantPublicId);
        if (ai != -1 && bi != -1) return ai.compareTo(bi);
        if (ai != -1) return -1;
        if (bi != -1) return 1;
        return 0;
      });
    }
    return filtered;
  }

  void _selectHospital(TenantSummary tenant) {
    _saveRecent(tenant.tenantPublicId);
    ref.read(hospitalProvider.notifier).selectHospital(tenant);
    context.go('/login');
  }

  void _retry() {
    setState(() => _tenantsFuture = ref.read(repositoryProvider).listTenants());
  }

  bool _isRecent(String id) => _recentIds.contains(id);

  @override
  Widget build(BuildContext context) {
    return AppShell(
      hospitalName: 'SevaCare',
      showBackButton: true,
      onBack: () => context.go('/'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Page header ────────────────────────────────────────────────────
          const PageHeader(
            title: 'Search Hospitals',
            subtitle: 'Select a hospital to continue',
          ),
          const SizedBox(height: 12),
          // ── Search field ───────────────────────────────────────────────────
          SearchField(
            controller: _searchController,
            placeholder: 'Search by name, city, or specialty…',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 20),
          // ── Results ────────────────────────────────────────────────────────
          FutureBuilder<List<TenantSummary>>(
            future: _tenantsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const _LoadingState();
              }
              if (snapshot.hasError) {
                return _ErrorState(
                  error: snapshot.error.toString(),
                  onRetry: _retry,
                );
              }
              final all = snapshot.data ?? [];
              final filtered = _sortAndFilter(all);

              if (filtered.isEmpty && _query.isNotEmpty) {
                return _EmptyState(query: _query);
              }
              if (filtered.isEmpty) {
                return _EmptyState(query: null);
              }

              final hasRecent = _recentIds.isNotEmpty && filtered.any((t) => _isRecent(t.tenantPublicId));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasRecent && _query.isEmpty) ...[
                    Text('Recently Visited', style: AppTextStyles.label(SevaCareColors.primary)),
                    const SizedBox(height: 6),
                  ] else ...[
                    Text(
                      '${filtered.length} hospital${filtered.length == 1 ? '' : 's'} found',
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Hospital cards
                  ...filtered.indexed.map(
                    ((int, TenantSummary) entry) {
                      final isRecent = _isRecent(entry.$2.tenantPublicId);
                      final showDivider = hasRecent && _query.isEmpty &&
                          !isRecent &&
                          (entry.$1 == 0 || _isRecent(filtered[entry.$1 - 1].tenantPublicId));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDivider) ...[
                            const SizedBox(height: 6),
                            Text('All Hospitals', style: AppTextStyles.label(SevaCareColors.textMuted)),
                            const SizedBox(height: 6),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HospitalCard(
                              tenant: entry.$2,
                              isRecent: isRecent,
                              onTap: () => _selectHospital(entry.$2),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Hospital Card ──────────────────────────────────────────────────────────────

class _HospitalCard extends ConsumerWidget {
  final TenantSummary tenant;
  final VoidCallback onTap;
  final bool isRecent;

  const _HospitalCard({required this.tenant, required this.onTap, this.isRecent = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hospital photo (if the platform admin uploaded one) — also warms the
    // cache so the login screen's glass background appears instantly.
    final heroBytes =
        ref.watch(tenantHeroImageProvider(tenant.tenantPublicId)).valueOrNull;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Left: avatar + text
          Expanded(
            child: Row(
              children: [
                // Hospital photo, else letter logomark
                if (heroBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    child: Image.memory(
                      heroBytes,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                else
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: SevaCareColors.buttonGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Center(
                      child: Text(
                        tenant.hospitalName.isNotEmpty
                            ? tenant.hospitalName[0].toUpperCase()
                            : 'H',
                        style: AppTextStyles.display(
                          size: 18,
                          weight: FontWeight.w700,
                          color: SevaCareColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                // Name and meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tenant.hospitalName,
                              style: AppTextStyles.cardTitle(SevaCareColors.text),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isRecent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: SevaCareColors.mintSoft,
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              ),
                              child: Text(
                                'Recent',
                                style: AppTextStyles.label(SevaCareColors.mintForeground),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${tenant.city} · ${tenant.specialty}',
                        style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => context.push('/explore/${tenant.tenantPublicId}', extra: tenant.hospitalName),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Explore Doctors',
                              style: AppTextStyles.label(SevaCareColors.primary).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_forward, size: 12, color: SevaCareColors.primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right: distance badge
          if (tenant.distance != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: SevaCareColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: SevaCareColors.border, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.near_me,
                    size: 11,
                    color: SevaCareColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tenant.distance!,
                    style: AppTextStyles.label(SevaCareColors.primary),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 4),
          // Chevron
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: SevaCareColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ── Loading State ──────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(SevaCareColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Loading hospitals…',
              style: TextStyle(
                fontSize: 13,
                color: SevaCareColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error State ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SevaCareColors.errorSurface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: SevaCareColors.danger.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline,
                    size: 18, color: SevaCareColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load hospitals',
                        style: AppTextStyles.cardTitle(SevaCareColors.danger),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error,
                        style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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

// ── Empty State ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String? query;

  const _EmptyState({this.query});

  @override
  Widget build(BuildContext context) {
    final hasQuery = query != null && query!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: SevaCareColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.local_hospital_outlined,
                size: 28,
                color: SevaCareColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No hospitals matched "$query"' : 'No hospitals available',
            style: AppTextStyles.cardTitle(SevaCareColors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Try a different name, city, or specialty.'
                : 'Please check your connection and try again.',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
