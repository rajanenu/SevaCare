import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/reverse_geocode.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// "Search Pharmacies" — the medical-store twin of [HospitalSearchScreen], and
/// deliberately the same journey: search a directory, pick your shop, then sign
/// in. Before this, the Pharmacy tile dropped the shopkeeper straight onto a
/// login form with no idea whether their store was even registered.
///
/// Only tenants with the pharmacy module are listed; the server filters
/// (`?module=pharmacy`), so a hospital with no dispensary never reaches here.
/// Green/teal throughout, matching the pharmacy login and counter.
class PharmacyStoreSearchScreen extends ConsumerStatefulWidget {
  const PharmacyStoreSearchScreen({super.key});

  @override
  ConsumerState<PharmacyStoreSearchScreen> createState() =>
      _PharmacyStoreSearchScreenState();
}

class _PharmacyStoreSearchScreenState
    extends ConsumerState<PharmacyStoreSearchScreen> {
  // Same green/teal identity as the pharmacy login and the counter shell.
  static const Color _accent = Color(0xFF15A66A);

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late Future<List<TenantSummary>> _storesFuture;
  List<String> _recentIds = [];
  bool _locating = false;
  String? _detectedPincode;
  String? _locationLabel;

  static const _prefsKey = 'recent_pharmacy_ids';
  static const _maxRecent = 3;

  @override
  void initState() {
    super.initState();
    _storesFuture = _fetch();
    _searchController
        .addListener(() => setState(() => _query = _searchController.text));
    _loadRecent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<TenantSummary>> _fetch() =>
      ref.read(repositoryProvider).listTenants(module: 'pharmacy');

  void _retry() => setState(() => _storesFuture = _fetch());

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && mounted) {
      setState(() => _recentIds = (jsonDecode(raw) as List).cast<String>());
    }
  }

  Future<void> _saveRecent(String id) async {
    final updated =
        [id, ..._recentIds.where((e) => e != id)].take(_maxRecent).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(updated));
    if (mounted) setState(() => _recentIds = updated);
  }

  bool _isRecent(String id) => _recentIds.contains(id);

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

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
      final place = await reverseGeocode(position.latitude, position.longitude);
      if (place == null || place.isEmpty || !mounted) return;
      final locality = place.locality!;
      final pincode = place.pincode;

      _searchController.text = locality;
      setState(() {
        _query = locality;
        _detectedPincode =
            (pincode != null && pincode.isNotEmpty) ? pincode : null;
        _locationLabel = (pincode != null && pincode.isNotEmpty)
            ? '${_capitalize(locality)}-$pincode'
            : _capitalize(locality);
      });
    } catch (_) {
      // Silently ignore — manual search remains available.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _clearDetectedLocation() {
    _searchController.clear();
    setState(() {
      _query = '';
      _detectedPincode = null;
      _locationLabel = null;
    });
  }

  List<TenantSummary> _sortAndFilter(List<TenantSummary> all) {
    final q = _query.trim().toLowerCase();
    final filtered = all.where((t) {
      if (q.isEmpty) return true;
      return t.hospitalName.toLowerCase().contains(q) ||
          t.city.toLowerCase().contains(q) ||
          (t.pinCode ?? '').contains(q);
    }).toList();

    // A store in the detected pincode outranks one merely in the same city;
    // a store you signed into before outranks a stranger.
    int priority(TenantSummary t) {
      if (_detectedPincode != null && t.pinCode == _detectedPincode) return 0;
      if (_isRecent(t.tenantPublicId)) return 1;
      return 2;
    }

    filtered.sort((a, b) {
      final pa = priority(a);
      final pb = priority(b);
      if (pa != pb) return pa.compareTo(pb);
      if (pa == 1) {
        return _recentIds
            .indexOf(a.tenantPublicId)
            .compareTo(_recentIds.indexOf(b.tenantPublicId));
      }
      return 0;
    });
    return filtered;
  }

  /// Hand the chosen store to the login screen, which then only has to ask
  /// "which mobile runs this shop?" — the same shape as picking a hospital.
  void _selectStore(TenantSummary store) {
    _saveRecent(store.tenantPublicId);
    context.go('/pharmacy-login', extra: store);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      hospitalName: 'SevaCare',
      showBackButton: true,
      onBack: () => context.go('/'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Search Pharmacies',
            subtitle: 'Select your medical store to continue',
          ),
          const SizedBox(height: 12),
          SearchField(
            controller: _searchController,
            placeholder: 'Search by store name, city, or PIN…',
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
                  : const Icon(Icons.my_location, size: 20, color: _accent),
            ),
          ),
          if (_locationLabel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me, size: 12, color: _accent),
                    const SizedBox(width: 4),
                    Text(_locationLabel!, style: AppTextStyles.label(_accent)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: _clearDetectedLocation,
                      child: const Icon(Icons.close, size: 14, color: _accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FutureBuilder<List<TenantSummary>>(
            future: _storesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _StoreErrorState(onRetry: _retry);
              }

              final filtered = _sortAndFilter(snapshot.data ?? []);
              if (filtered.isEmpty) {
                return _StoreEmptyState(query: _query);
              }

              final hasRecent = _query.isEmpty &&
                  filtered.any((t) => _isRecent(t.tenantPublicId));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    hasRecent
                        ? 'Recently Used'
                        : '${filtered.length} pharmac${filtered.length == 1 ? 'y' : 'ies'} found',
                    style: AppTextStyles.label(
                        hasRecent ? _accent : SevaCareColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  ...filtered.indexed.map(((int, TenantSummary) entry) {
                    final store = entry.$2;
                    final isRecent = _isRecent(store.tenantPublicId);
                    final showDivider = hasRecent &&
                        !isRecent &&
                        (entry.$1 == 0 ||
                            _isRecent(filtered[entry.$1 - 1].tenantPublicId));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDivider) ...[
                          const SizedBox(height: 6),
                          Text('All Pharmacies',
                              style:
                                  AppTextStyles.label(SevaCareColors.textMuted)),
                          const SizedBox(height: 6),
                        ],
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _StoreCard(
                            store: store,
                            isRecent: isRecent,
                            onTap: () => _selectStore(store),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Store card ────────────────────────────────────────────────────────────────

class _StoreCard extends StatelessWidget {
  static const Color _accent = Color(0xFF15A66A);

  final TenantSummary store;
  final bool isRecent;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.isRecent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SevaCareColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: SevaCareColors.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: const Icon(Icons.local_pharmacy_rounded,
                  color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Wrap, not Row — a long store name plus the "Recent" chip
                  // overflows on a narrow phone.
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        store.hospitalName,
                        style: AppTextStyles.cardTitle(SevaCareColors.text),
                      ),
                      if (isRecent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _accent.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text('Recent', style: AppTextStyles.label(_accent)),
                        ),
                      // A hospital that also dispenses is a legitimate result —
                      // say so, so the shopkeeper knows what they're signing into.
                      if (store.hasClinical)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SevaCareColors.primarySoft,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text('In-hospital',
                              style:
                                  AppTextStyles.label(SevaCareColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    store.pinCode == null || store.pinCode!.isEmpty
                        ? store.city
                        : '${store.city} · ${store.pinCode}',
                    style: AppTextStyles.body(
                        size: 12, color: SevaCareColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: SevaCareColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty / error states ──────────────────────────────────────────────────────

class _StoreEmptyState extends StatelessWidget {
  final String query;
  const _StoreEmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.local_pharmacy_outlined,
              size: 44, color: SevaCareColors.textMuted),
          const SizedBox(height: 10),
          Text(
            query.isEmpty
                ? 'No pharmacies registered yet'
                : 'No pharmacy matches "$query"',
            style: AppTextStyles.cardTitle(SevaCareColors.text),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            query.isEmpty
                ? 'Register your store from "Onboard Hospital / Pharmacy" on the home screen.'
                : 'Check the spelling, or search by city or PIN code.',
            style:
                AppTextStyles.body(size: 12, color: SevaCareColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StoreErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _StoreErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 44, color: SevaCareColors.textMuted),
          const SizedBox(height: 10),
          Text("Couldn't load pharmacies",
              style: AppTextStyles.cardTitle(SevaCareColors.text)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
