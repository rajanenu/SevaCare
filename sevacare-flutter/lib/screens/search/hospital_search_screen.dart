import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/reverse_geocode.dart';
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
  List<String> _favoriteIds = [];
  bool _locating = false;
  String? _detectedPincode;
  String? _locationLabel;

  static const _prefsKey = 'recent_hospital_ids';
  static const _maxRecent = 3;
  static const _favoritesPrefsKey = 'favorite_hospital_ids';

  @override
  void initState() {
    super.initState();
    // Hospitals only — a standalone medical store has no doctors to book and
    // must not appear here (it has its own list, under Search Pharmacies).
    _tenantsFuture = ref.read(repositoryProvider).listTenants(module: 'clinical');
    _searchController.addListener(() => setState(() => _query = _searchController.text));
    _loadRecent();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_favoritesPrefsKey);
    if (raw != null && mounted) {
      setState(() => _favoriteIds = (jsonDecode(raw) as List).cast<String>());
    }
  }

  Future<void> _toggleFavorite(String id) async {
    final updated = _favoriteIds.contains(id)
        ? _favoriteIds.where((e) => e != id).toList()
        : [..._favoriteIds, id];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoritesPrefsKey, jsonEncode(updated));
    if (mounted) setState(() => _favoriteIds = updated);
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Future<void> _detectLocationAndFillCity() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final place = await reverseGeocode(
        position.latitude,
        position.longitude,
      );
      if (place == null || place.isEmpty || !mounted) return;
      final locality = place.locality!;
      final pincode = place.pincode;

      final label = (pincode != null && pincode.isNotEmpty)
          ? '${_capitalize(locality)}-$pincode'
          : _capitalize(locality);

      _searchController.text = locality;
      setState(() {
        _query = locality;
        _detectedPincode = (pincode != null && pincode.isNotEmpty) ? pincode : null;
        _locationLabel = label;
      });
    } catch (_) {
      // Silently ignore — manual search remains available.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clearDetectedLocation() {
    setState(() {
      _detectedPincode = null;
      _locationLabel = null;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isPincodeMatch(TenantSummary t) =>
      _detectedPincode != null && t.pinCode != null && t.pinCode == _detectedPincode;

  List<TenantSummary> _sortAndFilter(List<TenantSummary> tenants) {
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? List<TenantSummary>.from(tenants)
        : tenants.where((t) {
            return t.hospitalName.toLowerCase().contains(q) ||
                t.city.toLowerCase().contains(q) ||
                t.specialty.toLowerCase().contains(q) ||
                _isPincodeMatch(t);
          }).toList();

    // Priority order: favorites > exact pincode match (from detected location)
    // > recently visited (preserving recency order) > everything else.
    int priority(TenantSummary t) {
      if (_isFavorite(t.tenantPublicId)) return 0;
      if (_isPincodeMatch(t)) return 1;
      if (_isRecent(t.tenantPublicId)) return 2;
      return 3;
    }

    filtered.sort((a, b) {
      final pa = priority(a);
      final pb = priority(b);
      if (pa != pb) return pa.compareTo(pb);
      if (pa == 2) {
        return _recentIds.indexOf(a.tenantPublicId).compareTo(_recentIds.indexOf(b.tenantPublicId));
      }
      return 0;
    });
    return filtered;
  }

  void _selectHospital(TenantSummary tenant) {
    _saveRecent(tenant.tenantPublicId);
    ref.read(hospitalProvider.notifier).selectHospital(tenant);
    context.go('/login');
  }

  void _retry() {
    setState(() => _tenantsFuture =
        ref.read(repositoryProvider).listTenants(module: 'clinical'));
  }

  bool _isRecent(String id) => _recentIds.contains(id);
  bool _isFavorite(String id) => _favoriteIds.contains(id);

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
            suffixIcon: IconButton(
              onPressed: _locating ? null : _detectLocationAndFillCity,
              tooltip: 'Use my location',
              icon: _locating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location, size: 20, color: context.colors.primary),
            ),
          ),
          if (_locationLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: context.colors.primarySoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.near_me, size: 12, color: context.colors.primary),
                    const SizedBox(width: 4),
                    Text(_locationLabel!, style: AppTextStyles.label(context.colors.primary)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _clearDetectedLocation,
                      child: Icon(Icons.close, size: 14, color: context.colors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
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

              final hasFavorites = _favoriteIds.isNotEmpty && filtered.any((t) => _isFavorite(t.tenantPublicId));
              final hasRecent = _recentIds.isNotEmpty && filtered.any((t) => _isRecent(t.tenantPublicId));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasFavorites && _query.isEmpty) ...[
                    Text('Favorites', style: AppTextStyles.label(context.colors.primary)),
                    const SizedBox(height: 6),
                  ] else if (hasRecent && _query.isEmpty) ...[
                    Text('Recently Visited', style: AppTextStyles.label(context.colors.primary)),
                    const SizedBox(height: 6),
                  ] else ...[
                    Text(
                      '${filtered.length} hospital${filtered.length == 1 ? '' : 's'} found',
                      style: AppTextStyles.label(context.colors.textMuted),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // Hospital cards
                  ...filtered.indexed.map(
                    ((int, TenantSummary) entry) {
                      final isFavorite = _isFavorite(entry.$2.tenantPublicId);
                      final isRecent = _isRecent(entry.$2.tenantPublicId);
                      final showFavDivider = hasFavorites && _query.isEmpty &&
                          !isFavorite &&
                          (entry.$1 == 0 || _isFavorite(filtered[entry.$1 - 1].tenantPublicId));
                      final showRecentDivider = !showFavDivider && hasRecent && _query.isEmpty &&
                          !isRecent && !isFavorite &&
                          (entry.$1 == 0 || _isRecent(filtered[entry.$1 - 1].tenantPublicId) || _isFavorite(filtered[entry.$1 - 1].tenantPublicId));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showFavDivider) ...[
                            const SizedBox(height: 6),
                            Text(hasRecent ? 'Recently Visited' : 'All Hospitals', style: AppTextStyles.label(context.colors.textMuted)),
                            const SizedBox(height: 6),
                          ] else if (showRecentDivider) ...[
                            const SizedBox(height: 6),
                            Text('All Hospitals', style: AppTextStyles.label(context.colors.textMuted)),
                            const SizedBox(height: 6),
                          ],
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _HospitalCard(
                              tenant: entry.$2,
                              isRecent: isRecent,
                              isFavorite: isFavorite,
                              onTap: () => _selectHospital(entry.$2),
                              onToggleFavorite: () => _toggleFavorite(entry.$2.tenantPublicId),
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
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  const _HospitalCard({
    required this.tenant,
    required this.onTap,
    required this.onToggleFavorite,
    this.isRecent = false,
    this.isFavorite = false,
  });

  Future<void> _showQrDialog(BuildContext context, WidgetRef ref) async {
    String? qrLink;
    try {
      final result =
          await ref.read(repositoryProvider).getPublicTenantQrCode(tenant.tenantPublicId);
      final uuid = result['qrcodeUuid'] as String? ?? '';
      if (uuid.isNotEmpty) {
        qrLink = '${AppConfig.apiBaseUrl}/public/qrcode/$uuid/book';
      }
    } catch (_) {}
    if (!context.mounted) return;
    if (qrLink == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code is not available right now.')),
      );
      return;
    }
    final link = qrLink;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tenant.hospitalName,
            style: AppTextStyles.sectionTitle(context.colors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 224,
              height: 224,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border, width: 1),
              ),
              child: QrImageView(
                data: link,
                version: QrVersions.auto,
                size: 200,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Scan with your phone camera to book an appointment — no login needed.',
              style: AppTextStyles.bodyText(context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hospital photo (if the platform admin uploaded one) — also warms the
    // cache so the login screen's glass background appears instantly.
    final heroBytes =
        ref.watch(tenantHeroImageProvider(tenant.tenantPublicId)).valueOrNull;

    // Two-line layout: the top row is only avatar + name/meta + favorite +
    // chevron, so the hospital name always gets the full width. Chips
    // (Recent, distance) and the Explore/QR links live on a bottom Wrap that
    // flows to a second line on narrow screens instead of truncating anything.
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    gradient: LinearGradient(
                      colors: context.colors.buttonGradient,
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
                        color: context.colors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            tenant.hospitalName,
                            style: AppTextStyles.cardTitle(context.colors.text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isRecent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.colors.mintSoft,
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            ),
                            child: Text(
                              'Recent',
                              style: AppTextStyles.label(context.colors.mintForeground),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant.city,
                            style: AppTextStyles.bodyText(context.colors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (tenant.distance != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.colors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                              border: Border.all(color: context.colors.border, width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.near_me,
                                  size: 11,
                                  color: context.colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tenant.distance!,
                                  style: AppTextStyles.label(context.colors.primary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              // Favorite toggle
              InkWell(
                onTap: onToggleFavorite,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: isFavorite ? context.colors.danger : context.colors.textMuted,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Bottom line: links left, status chips right ────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 56),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // behavior: opaque + padding = a generous hit target; with
                // deferToChild, taps landing between the tiny glyphs fell
                // through to the card's own onTap (login) — which is why this
                // link "sometimes didn't work".
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/explore/${tenant.tenantPublicId}', extra: tenant.hospitalName),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Explore Doctors',
                          style: AppTextStyles.label(context.colors.primary).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward, size: 12, color: context.colors.primary),
                      ],
                    ),
                  ),
                ),
                // Booking QR — tap to enlarge and scan.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showQrDialog(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_2, size: 15, color: context.colors.primary),
                        const SizedBox(width: 2),
                        Text(
                          'QR',
                          style: AppTextStyles.label(context.colors.primary).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
      padding: EdgeInsets.only(top: 8),
      child: ShimmerList(count: 4, cardHeight: 84),
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
              color: context.colors.errorSurface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(
                color: context.colors.danger.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline,
                    size: 18, color: context.colors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Could not load hospitals',
                        style: AppTextStyles.cardTitle(context.colors.danger),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        error,
                        style: AppTextStyles.bodyText(context.colors.textMuted),
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
              color: context.colors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                Icons.local_hospital_outlined,
                size: 28,
                color: context.colors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'No hospitals matched "$query"' : 'No hospitals available',
            style: AppTextStyles.cardTitle(context.colors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Try a different name, city, or specialty.'
                : 'Please check your connection and try again.',
            style: AppTextStyles.bodyText(context.colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
