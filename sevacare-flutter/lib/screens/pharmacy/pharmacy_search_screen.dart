import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/masked_text.dart';

/// The counter's own search. Behind a shop counter "search" never means a
/// doctor — it means "where is that medicine", "who supplies it", "which bill
/// was that". One box searches all three at once and the results say which is
/// which, so the pharmacist doesn't have to choose a category first.
class PharmacySearchScreen extends ConsumerStatefulWidget {
  const PharmacySearchScreen({super.key});

  @override
  ConsumerState<PharmacySearchScreen> createState() => _PharmacySearchScreenState();
}

enum _Scope { all, medicines, suppliers, invoices }

class _PharmacySearchScreenState extends ConsumerState<PharmacySearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';
  _Scope _scope = _Scope.all;

  List<PharmacySku> _catalog = [];
  List<Supplier> _suppliers = [];
  List<SaleSummary> _sales = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Everything the counter searches is small enough to hold in memory (a shop's
  /// catalog, its suppliers, a quarter of bills), so we load once and filter on
  /// each keystroke — no round trip per letter.
  Future<void> _load() async {
    final auth = ref.read(authProvider);
    final repo = ref.read(repositoryProvider);
    if (auth.tenantPublicId == null || auth.token == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final tenant = auth.tenantPublicId!, token = auth.token!;
    try {
      final catalog = await repo.catalogStock(tenant, token);
      List<Supplier> suppliers = [];
      List<SaleSummary> sales = [];
      try {
        suppliers = await repo.listSuppliers(tenant, token);
      } catch (_) {/* a store may have none */}
      try {
        sales = await repo.salesInRange(
          tenant,
          token,
          _iso(DateTime.now().subtract(const Duration(days: 90))),
          _iso(DateTime.now()),
        );
      } catch (_) {/* bills section just stays empty */}
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _suppliers = suppliers;
        _sales = sales;
      });
    } catch (_) {/* empty results, the field still works */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PharmacySku> get _medHits {
    if (_q.isEmpty) return const [];
    return _catalog
        .where((s) =>
            s.brandName.toLowerCase().contains(_q) ||
            (s.manufacturer ?? '').toLowerCase().contains(_q) ||
            (s.rackLocation ?? '').toLowerCase().contains(_q))
        .toList()
      ..sort((a, b) {
        final ap = a.brandName.toLowerCase().startsWith(_q) ? 0 : 1;
        final bp = b.brandName.toLowerCase().startsWith(_q) ? 0 : 1;
        if (ap != bp) return ap - bp;
        return a.brandName.compareTo(b.brandName);
      });
  }

  List<Supplier> get _supplierHits => _q.isEmpty
      ? const []
      : _suppliers
          .where((s) =>
              s.supplierName.toLowerCase().contains(_q) ||
              (s.city ?? '').toLowerCase().contains(_q) ||
              (s.gstin ?? '').toLowerCase().contains(_q) ||
              (s.mobileNumber ?? '').contains(_q))
          .toList();

  List<SaleSummary> get _invoiceHits => _q.isEmpty
      ? const []
      : _sales
          .where((s) =>
              s.invoiceNo.toLowerCase().contains(_q) ||
              (s.customerName ?? '').toLowerCase().contains(_q) ||
              (s.customerMobile ?? '').contains(_q))
          .toList();

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final meds = _medHits, sups = _supplierHits, invs = _invoiceHits;
    final showMeds = _scope == _Scope.all || _scope == _Scope.medicines;
    final showSups = _scope == _Scope.all || _scope == _Scope.suppliers;
    final showInvs = _scope == _Scope.all || _scope == _Scope.invoices;
    final nothing = (showMeds ? meds.length : 0) +
            (showSups ? sups.length : 0) +
            (showInvs ? invs.length : 0) ==
        0;

    return AppShell(
      hospitalName: auth.capabilities?.tenantName ?? 'Pharmacy',
      role: auth.role,
      showBackButton: true,
      onBack: () => context.pop(),
      helpRoute: '/pharmacy/help',
      homeRoute: '/pharmacy',
      searchRoute: '/pharmacy/search',
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: _loading
                  ? 'Loading the shop…'
                  : 'Medicine, supplier, invoice no. or customer…',
              prefixIcon: const Icon(Icons.search_rounded, color: SevaCareColors.primary),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _ctrl.clear();
                        setState(() => _q = '');
                      },
                    ),
              filled: true,
              fillColor: SevaCareColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: SevaCareColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: SevaCareColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final s in _Scope.values)
              ChoiceChip(
                label: Text(switch (s) {
                  _Scope.all => 'Everything',
                  _Scope.medicines => 'Medicines (${meds.length})',
                  _Scope.suppliers => 'Suppliers (${sups.length})',
                  _Scope.invoices => 'Invoices (${invs.length})',
                }),
                selected: _scope == s,
                onSelected: (_) => setState(() => _scope = s),
                selectedColor: SevaCareColors.primarySoft,
              ),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: _q.isEmpty
                ? _hint()
                : nothing
                    ? _empty()
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (showMeds && meds.isNotEmpty) ...[
                            _sectionTitle('Medicines', Icons.medication_outlined, meds.length),
                            for (final m in meds.take(40)) _medTile(m),
                            const SizedBox(height: 12),
                          ],
                          if (showSups && sups.isNotEmpty) ...[
                            _sectionTitle('Suppliers', Icons.local_shipping_outlined, sups.length),
                            for (final s in sups) _supplierTile(s),
                            const SizedBox(height: 12),
                          ],
                          if (showInvs && invs.isNotEmpty) ...[
                            _sectionTitle('Invoices (last 90 days)', Icons.receipt_long_outlined, invs.length),
                            for (final s in invs.take(40)) _invoiceTile(s),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t, IconData icon, int n) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: SevaCareColors.primary),
          const SizedBox(width: 6),
          Text('$t · $n',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      );

  Widget _hint() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.storefront_outlined, size: 46, color: SevaCareColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          const Text('Search your shop', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Medicines with their rack and stock, suppliers with their numbers, '
              'and any bill from the last 90 days.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: SevaCareColors.textMuted),
            ),
          ),
        ]),
      );

  Widget _empty() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 40, color: SevaCareColors.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('Nothing matches “${_ctrl.text.trim()}”.',
              style: const TextStyle(color: SevaCareColors.textMuted)),
        ]),
      );

  Widget _medTile(PharmacySku s) {
    final out = s.qtyOnHand <= 0;
    return GlassCard(
      borderWidth: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              [
                if ((s.strength ?? '').isNotEmpty) s.strength,
                if ((s.dosageForm ?? '').isNotEmpty) s.dosageForm,
                if ((s.manufacturer ?? '').isNotEmpty) s.manufacturer,
                if (s.isPrescriptionOnly) 'Rx ${s.scheduleClass ?? ''}'.trim(),
              ].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted),
            ),
            if ((s.rackLocation ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(children: [
                  const Icon(Icons.shelves, size: 12, color: SevaCareColors.primary),
                  const SizedBox(width: 4),
                  Text('Rack ${s.rackLocation}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: SevaCareColors.primary)),
                ]),
              ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (s.mrpPaise > 0)
            Text('₹${(s.mrpPaise / 100).toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(out ? 'out of stock' : '${s.qtyOnHand} in stock',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: out ? SevaCareColors.error : SevaCareColors.textMuted,
              )),
        ]),
      ]),
    );
  }

  Future<void> _dial(String scheme, String value) async {
    final uri = Uri(scheme: scheme, path: value);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing on this device can open that.')));
    }
  }

  Widget _supplierTile(Supplier s) {
    final mobile = (s.mobileNumber ?? '').trim();
    final email = (s.email ?? '').trim();
    return GlassCard(
      borderWidth: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.supplierName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              [
                if (mobile.isNotEmpty) mobile,
                if (email.isNotEmpty) email,
                if ((s.city ?? '').isNotEmpty) s.city,
                if ((s.gstin ?? '').isNotEmpty) 'GSTIN ${s.gstin}',
                'returns ${s.returnWindowDays}d',
              ].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted),
            ),
          ]),
        ),
        if (mobile.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.call_outlined, size: 18, color: SevaCareColors.success),
            tooltip: 'Call',
            onPressed: () => _dial('tel', mobile),
          ),
        if (email.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.email_outlined, size: 18, color: SevaCareColors.primary),
            tooltip: 'Email',
            onPressed: () => _dial('mailto', email),
          ),
      ]),
    );
  }

  Widget _invoiceTile(SaleSummary s) => GlassCard(
        borderWidth: 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(s.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (s.isVoid) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: SevaCareColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('VOID',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SevaCareColors.error)),
                  ),
                ],
              ]),
              Row(children: [
                Text('${(s.soldAt ?? '').split('T').first} · ${s.paymentMode}',
                    style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                if ((s.customerName ?? '').isNotEmpty)
                  Text(' · ${s.customerName}',
                      style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                if ((s.customerMobile ?? '').isNotEmpty) ...[
                  const Text(' · ', style: TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                  MaskedText(s.customerMobile!,
                      style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                ],
              ]),
            ]),
          ),
          Text('₹${(s.totalPaise / 100).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
