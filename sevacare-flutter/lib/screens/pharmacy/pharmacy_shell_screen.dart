import 'dart:convert';

// The spreadsheet package ships its own Border/BorderStyle for cell styling;
// hidden here so Material's win — this file draws widgets, not cells.
import 'package:excel/excel.dart' hide Border, BorderStyle;
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/mobile_input_formatter.dart';
import '../../core/utils/pharmacy_gst_summary_pdf.dart';
import '../../core/utils/pharmacy_receipt_pdf.dart';
import '../../core/utils/pharmacy_sales_register_pdf.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/app_form_field.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/masked_text.dart';

String _rupees(int paise) => '₹${(paise / 100).toStringAsFixed(2)}';

/// The visual language for a medicine's form — a colour and an icon so the owner
/// recognises a syrup from a strip at a glance, on the shelf and on the bill.
/// Keyed off the dosage form first, then the base unit as a fallback.
class _MedStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _MedStyle(this.color, this.icon, this.label);
}

_MedStyle _medStyleOf(String? dosageForm, String? baseUnit) {
  final f = (dosageForm ?? '').toUpperCase();
  final u = (baseUnit ?? '').toUpperCase();
  bool has(String s) => f.contains(s);
  if (has('SYRUP') || has('LIQUID') || has('SUSPENSION') || has('ELIXIR') || u == 'ML') {
    return const _MedStyle(Color(0xFF14B8A6), Icons.medication_liquid, 'Syrup');
  }
  if (has('INJECT') || has('VIAL') || has('AMPOULE') || has('VACCINE')) {
    return const _MedStyle(Color(0xFFEF4444), Icons.vaccines, 'Injection');
  }
  if (has('DROP')) {
    return const _MedStyle(Color(0xFF06B6D4), Icons.water_drop, 'Drops');
  }
  if (has('CREAM') || has('OINT') || has('GEL') || has('LOTION') || has('BALM')) {
    return const _MedStyle(Color(0xFF8B5CF6), Icons.sanitizer, 'Topical');
  }
  if (has('CAP')) {
    return const _MedStyle(Color(0xFFF59E0B), Icons.medication, 'Capsule');
  }
  if (has('POWDER') || has('SACHET') || has('GRANULE')) {
    return const _MedStyle(Color(0xFF84CC16), Icons.grain, 'Powder');
  }
  if (has('TAB') || u == 'TABLET') {
    return const _MedStyle(Color(0xFF3B82F6), Icons.medication_outlined, 'Tablet');
  }
  return const _MedStyle(Color(0xFF64748B), Icons.medical_services_outlined, 'Item');
}

/// A small square colour-coded badge for a medicine's form.
class _MedBadge extends StatelessWidget {
  final String? dosageForm;
  final String? baseUnit;
  final double size;
  const _MedBadge({this.dosageForm, this.baseUnit, this.size = 38});

  @override
  Widget build(BuildContext context) {
    final s = _medStyleOf(dosageForm, baseUnit);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: s.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
      child: Icon(s.icon, size: size * 0.52, color: s.color),
    );
  }
}

/// The four ways money comes across the counter, each an icon and a fixed
/// brand color the eye finds faster than a word — cash is the green of a
/// note, UPI the purple of the app icons, card blue, credit amber.
const List<(String, IconData, String, Color)> _paymentModes = [
  ('CASH', Icons.payments_outlined, 'Cash', Color(0xFF16A34A)),
  ('UPI', Icons.qr_code_2, 'UPI', Color(0xFF7C3AED)),
  ('CARD', Icons.credit_card, 'Card', Color(0xFF2563EB)),
  ('CREDIT', Icons.account_balance_wallet_outlined, 'Credit', Color(0xFFD97706)),
];

/// Shared colorful icon-chip payment picker, used by both the sale checkout
/// and the refund sheet so money always looks the same regardless of
/// direction. `codes` narrows which of `_paymentModes` to show.
class _PaymentModeChips extends StatelessWidget {
  final List<String> codes;
  final String selected;
  final ValueChanged<String> onChanged;
  const _PaymentModeChips({required this.codes, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final modes = _paymentModes.where((m) => codes.contains(m.$1)).toList();
    return Row(children: [
      for (final m in modes)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onChanged(m.$1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected == m.$1 ? m.$4.withValues(alpha: 0.14) : SevaCareColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == m.$1 ? m.$4 : SevaCareColors.border,
                    width: selected == m.$1 ? 1.5 : 1,
                  ),
                ),
                child: Column(children: [
                  Icon(m.$2, size: 20, color: selected == m.$1 ? m.$4 : SevaCareColors.textMuted),
                  const SizedBox(height: 4),
                  Text(m.$3, style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected == m.$1 ? m.$4 : SevaCareColors.textMuted,
                  )),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}


/// The pharmacy counter. Three jobs, three tabs: Sell (the twenty-second sale),
/// Stock (receive deliveries, watch expiry and reorder), and Today (the day-close
/// and recent bills). Deliberately plain — a shop assistant should understand it
/// without training.
class PharmacyShellScreen extends ConsumerStatefulWidget {
  const PharmacyShellScreen({super.key});

  @override
  ConsumerState<PharmacyShellScreen> createState() => _PharmacyShellScreenState();
}

class _PharmacyShellScreenState extends ConsumerState<PharmacyShellScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // If we arrived without capabilities (e.g. a biometric session restore),
    // fetch them so the header can name the shop; failure is harmless.
    Future.microtask(() async {
      final auth = ref.read(authProvider);
      if (auth.capabilities == null && auth.tenantPublicId != null && auth.token != null) {
        try {
          final caps = await ref
              .read(repositoryProvider)
              .getCapabilities(auth.tenantPublicId!, auth.token!);
          if (mounted) ref.read(authProvider.notifier).setCapabilities(caps);
        } catch (_) {/* header just shows the default name */}
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final name = auth.capabilities?.tenantName ?? 'Pharmacy';

    const tabs = [
      _TabDef('Sell', Icons.point_of_sale_outlined),
      _TabDef('Stock', Icons.inventory_2_outlined),
      _TabDef('Team', Icons.group_outlined),
      _TabDef('Dashboard', Icons.insights_outlined),
    ];

    return AppShell(
      hospitalName: name,
      role: auth.role,
      scrollable: false,
      showBackButton: false,
      helpRoute: '/pharmacy/help',
      searchRoute: '/pharmacy/search',
      homeRoute: '/pharmacy',
      headerActions: [
        IconButton(
          icon: const Icon(Icons.person_outline),
          color: SevaCareColors.textMuted,
          tooltip: 'Profile',
          onPressed: () => context.push('/pharmacy/profile'),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _SegmentedTabs(
              tabs: tabs,
              current: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: const [
                _SellTab(),
                _StockTab(),
                _TeamTab(),
                _TodayTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}

class _SegmentedTabs extends StatelessWidget {
  final List<_TabDef> tabs;
  final int current;
  final ValueChanged<int> onChanged;
  const _SegmentedTabs({required this.tabs, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Four icon+label tabs need ~90dp each. On a narrow phone that overflows,
      // so below that only the selected tab keeps its word — the icons carry the
      // rest, and nothing is ever clipped.
      final perTab = c.maxWidth / tabs.length;
      final labelAll = perTab >= 92;
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: SevaCareColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: Semantics(
                  label: tabs[i].label,
                  button: true,
                  selected: current == i,
                  child: GestureDetector(
                    onTap: () => onChanged(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                      decoration: BoxDecoration(
                        color: current == i ? SevaCareColors.surface : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        boxShadow: current == i
                            ? [BoxShadow(color: SevaCareColors.shadowColor.withValues(alpha: 0.08), blurRadius: 8)]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tabs[i].icon, size: 18,
                              color: current == i ? SevaCareColors.primary : SevaCareColors.textMuted),
                          if (labelAll || current == i) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                tabs[i].label,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: current == i ? SevaCareColors.primary : SevaCareColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

/// A collapsible section — the counter's screens carry a lot of standing
/// information (bills, low stock, deliveries) that a pharmacist wants *on
/// demand*, not in the way of the next customer. Closed by default unless the
/// content is safety-critical.
class _Accordion extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final int? count;
  final bool initiallyOpen;
  final Widget child;
  const _Accordion({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.subtitle,
    this.count,
    this.initiallyOpen = false,
  });

  @override
  State<_Accordion> createState() => _AccordionState();
}

class _AccordionState extends State<_Accordion> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SevaCareColors.border, width: 0.8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(widget.icon, size: 18, color: widget.color),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  if (widget.subtitle != null)
                    Text(widget.subtitle!,
                        style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                ]),
              ),
              if (widget.count != null && widget.count! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${widget.count}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color)),
                ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: const Icon(Icons.expand_more, color: SevaCareColors.textMuted),
              ),
            ]),
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: widget.child,
          ),
      ]),
    );
  }
}

// ── Sell ────────────────────────────────────────────────────────────────────

/// A cart line is either a catalog SKU or a manual, non-catalog charge (a
/// courier bag, a delivery fee) — `sku` is null for the latter, and
/// `manualLabel`/`manualAmountPaise` carry the flat amount instead.
class _CartLine {
  final PharmacySku? sku;
  int qty;
  final String? manualLabel;
  final int? manualAmountPaise;

  _CartLine(this.sku, this.qty)
      : manualLabel = null,
        manualAmountPaise = null;

  _CartLine.manual(String label, int amountPaise)
      : sku = null,
        qty = 1,
        manualLabel = label,
        manualAmountPaise = amountPaise;

  bool get isManual => sku == null;

  int get lineTotalPaise => isManual ? manualAmountPaise! : sku!.mrpPaise * qty;
}

/// A sale parked mid-entry — the customer stepped away for cash, and the next
/// person in line shouldn't have to wait for them. Pre-payment, so nothing
/// here is a business record yet; it lives only in this screen's memory.
class _HeldSale {
  final List<_CartLine> cart;
  final String customerName;
  final String customerMobile;
  final String prescriber;
  final String payment;
  final DateTime heldAt;
  _HeldSale({
    required this.cart,
    required this.customerName,
    required this.customerMobile,
    required this.prescriber,
    required this.payment,
  }) : heldAt = DateTime.now();
}

class _SellTab extends ConsumerStatefulWidget {
  const _SellTab();
  @override
  ConsumerState<_SellTab> createState() => _SellTabState();
}

class _SellTabState extends ConsumerState<_SellTab> {
  final _searchCtrl = TextEditingController();
  final _prescriberCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerMobileCtrl = TextEditingController();

  /// The whole catalog, loaded once and searched locally so a keystroke costs
  /// nothing. Kept fresh by a pull-to-refresh and decremented as items sell.
  final Map<String, PharmacySku> _catalog = {};
  List<TopMedicine> _frequent = [];
  List<PharmacySku> _results = [];
  final List<_CartLine> _cart = [];
  String _payment = 'CASH';
  bool _loadingCatalog = true;
  bool _submitting = false;
  bool _showCustomer = true;

  // Repeat last purchase — a regular's mobile suggests their last bill.
  SaleReceipt? _lastPurchase;
  String _lastPurchaseCheckedFor = '';

  // Khata: dues shown the moment a known credit customer's mobile is typed.
  CreditOutstanding? _customerDues;

  // Held (parked) sales — pre-payment, so purely client-side.
  final List<_HeldSale> _held = [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _prescriberCtrl.dispose();
    _customerNameCtrl.dispose();
    _customerMobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final auth = ref.read(authProvider);
    if (auth.tenantPublicId == null || auth.token == null) {
      setState(() => _loadingCatalog = false);
      return;
    }
    setState(() => _loadingCatalog = true);
    try {
      final repo = ref.read(repositoryProvider);
      final stock = await repo.catalogStock(auth.tenantPublicId!, auth.token!);
      List<TopMedicine> frequent = [];
      try {
        frequent = await repo.topMedicines(auth.tenantPublicId!, auth.token!, period: 'MONTH', limit: 10);
      } catch (_) {/* frequent chips are a bonus, not required */}
      if (!mounted) return;
      setState(() {
        _catalog
          ..clear()
          ..addEntries(stock.map((s) => MapEntry(s.skuPublicId, s)));
        _frequent = frequent;
      });
    } catch (_) {
      // Fall back to server-side search if the bulk load fails.
    } finally {
      if (mounted) setState(() => _loadingCatalog = false);
    }
  }

  /// Local, instant search over the cached catalog — matches from the first
  /// letter, prefixes rank above mid-word hits. Falls back to the server only if
  /// the catalog never loaded.
  Future<void> _search(String q) async {
    final needle = q.trim().toLowerCase();
    if (needle.isEmpty) {
      setState(() => _results = []);
      return;
    }
    if (_catalog.isNotEmpty) {
      final all = _catalog.values.toList();
      final matches = all.where((s) {
        final b = s.brandName.toLowerCase();
        final m = (s.manufacturer ?? '').toLowerCase();
        return b.contains(needle) || m.contains(needle);
      }).toList()
        ..sort((a, b) {
          final ap = a.brandName.toLowerCase().startsWith(needle) ? 0 : 1;
          final bp = b.brandName.toLowerCase().startsWith(needle) ? 0 : 1;
          if (ap != bp) return ap - bp;
          return a.brandName.toLowerCase().compareTo(b.brandName.toLowerCase());
        });
      setState(() => _results = matches.take(25).toList());
      return;
    }
    if (needle.length < 3) return;
    final auth = ref.read(authProvider);
    try {
      final r = await ref.read(repositoryProvider).searchCatalog(auth.tenantPublicId!, auth.token!, q.trim());
      if (mounted) setState(() => _results = r);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    }
  }

  int _qtyInCart(String skuId) =>
      _cart.where((c) => c.sku?.skuPublicId == skuId).fold(0, (s, c) => s + c.qty);

  /// Remaining on-hand for a SKU, net of what is already in the current bill.
  int _remaining(PharmacySku sku) => sku.qtyOnHand - _qtyInCart(sku.skuPublicId);

  void _addToCart(PharmacySku sku, {int qty = 1}) {
    final existing = _cart.where((c) => c.sku?.skuPublicId == sku.skuPublicId).toList();
    setState(() {
      if (existing.isNotEmpty) {
        existing.first.qty += qty;
      } else {
        _cart.add(_CartLine(sku, qty));
      }
      _searchCtrl.clear();
      _results = [];
    });
  }

  void _addFrequent(TopMedicine t) {
    final sku = _catalog[t.skuPublicId];
    if (sku == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That medicine is no longer in the catalog.')));
      return;
    }
    _addToCart(sku);
  }

  /// A charge that isn't in the catalog — a courier bag, a delivery fee — the
  /// pharmacist types a label and an amount, and it bills like any other line.
  Future<void> _addOthers() async {
    final labelCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add a charge'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('For anything that is not a catalog medicine — a courier bag, a delivery charge.',
              style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 12),
          TextField(controller: labelCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          TextField(
            controller: amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (result != true) return;
    final label = labelCtrl.text.trim();
    final amount = double.tryParse(amountCtrl.text.trim());
    if (label.isEmpty || amount == null || amount <= 0) return;
    setState(() => _cart.add(_CartLine.manual(label, (amount * 100).round())));
  }

  Future<void> _editQty(_CartLine line) async {
    final sku = line.sku!;
    final ctrl = TextEditingController(text: '${line.qty}');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sku.brandName),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How many ${sku.baseUnit.toLowerCase()} to sell? '
              'A strip of 10 with only 5 needed is simply 5 here.',
              style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(suffixText: sku.baseUnit.toLowerCase()),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Set'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) setState(() => line.qty = result);
  }

  int get _subtotalPaise => _cart.fold(0, (s, c) => s + c.lineTotalPaise);

  Future<void> _completeSale() async {
    if (_cart.isEmpty) return;
    final auth = ref.read(authProvider);
    setState(() => _submitting = true);
    try {
      final body = {
        'paymentMode': _payment,
        if (_customerNameCtrl.text.trim().isNotEmpty) 'customerName': _customerNameCtrl.text.trim(),
        if (_customerMobileCtrl.text.trim().isNotEmpty) 'customerMobile': _customerMobileCtrl.text.trim(),
        if (_prescriberCtrl.text.trim().isNotEmpty) 'prescriberName': _prescriberCtrl.text.trim(),
        'lines': _cart.map((c) => c.isManual
            ? {'manualLabel': c.manualLabel, 'manualAmountPaise': c.manualAmountPaise, 'qtyBaseUnits': 1}
            : {'skuPublicId': c.sku!.skuPublicId, 'qtyBaseUnits': c.qty}).toList(),
      };
      final receipt = await ref.read(repositoryProvider).createSale(auth.tenantPublicId!, auth.token!, body);
      if (!mounted) return;
      // Reflect the dispense in the cached on-hand so "remaining" stays honest
      // until the next full refresh.
      for (final c in _cart) {
        if (c.isManual) continue;
        final cached = _catalog[c.sku!.skuPublicId];
        if (cached != null) {
          _catalog[c.sku!.skuPublicId] = cached.withQtyOnHand(cached.qtyOnHand - c.qty);
        }
      }
      setState(() {
        _cart.clear();
        _prescriberCtrl.clear();
        _customerNameCtrl.clear();
        _customerMobileCtrl.clear();
        _showCustomer = true;
        _lastPurchase = null;
        _customerDues = null;
        _lastPurchaseCheckedFor = '';
      });
      await _showReceipt(receipt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Repeat last purchase ─────────────────────────────────────────────────

  Future<void> _onCustomerMobileChanged(String value) async {
    setState(() {});
    final mobile = value.trim();
    if (mobile.length != 10) {
      if (_lastPurchase != null || _customerDues != null) {
        setState(() { _lastPurchase = null; _customerDues = null; _lastPurchaseCheckedFor = ''; });
      }
      return;
    }
    if (mobile == _lastPurchaseCheckedFor) return;
    _lastPurchaseCheckedFor = mobile;
    final auth = ref.read(authProvider);
    final repo = ref.read(repositoryProvider);
    final receipt = await repo.lastSaleForMobile(auth.tenantPublicId!, auth.token!, mobile);
    final dues = await repo.creditOutstandingFor(auth.tenantPublicId!, auth.token!, mobile);
    if (mounted && _customerMobileCtrl.text.trim() == mobile) {
      setState(() {
        _lastPurchase = receipt;
        _customerDues = (dues != null && dues.outstandingPaise > 0) ? dues : null;
      });
    }
  }

  Widget _rebillChip() {
    final r = _lastPurchase!;
    return ActionChip(
      avatar: const Icon(Icons.replay, size: 16, color: SevaCareColors.primary),
      label: Text('Same as last time (${_rupees(r.totalPaise)}, ${r.lines.length} item${r.lines.length == 1 ? '' : 's'}) · Rebill'),
      onPressed: _rebillLast,
    );
  }

  /// Re-adds the SKUs from the customer's last bill at today's stock and
  /// price. Lines whose SKU no longer exists (discontinued, or a manual
  /// non-catalog charge) are silently skipped — there's nothing to re-add.
  void _rebillLast() {
    final r = _lastPurchase;
    if (r == null) return;
    int added = 0, skipped = 0;
    setState(() {
      for (final line in r.lines) {
        final sku = _catalog[line.skuPublicId];
        if (sku == null) { skipped++; continue; }
        _addToCart(sku, qty: line.qtyBaseUnits);
        added++;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        skipped == 0 ? 'Added $added item${added == 1 ? '' : 's'} from the last bill.'
            : 'Added $added item${added == 1 ? '' : 's'}; $skipped no longer in the catalog.')));
  }

  // ── Hold / park a sale ───────────────────────────────────────────────────

  void _parkSale() {
    if (_cart.isEmpty) return;
    setState(() {
      _held.add(_HeldSale(
        cart: List.of(_cart),
        customerName: _customerNameCtrl.text.trim(),
        customerMobile: _customerMobileCtrl.text.trim(),
        prescriber: _prescriberCtrl.text.trim(),
        payment: _payment,
      ));
      _cart.clear();
      _customerNameCtrl.clear();
      _customerMobileCtrl.clear();
      _prescriberCtrl.clear();
      _payment = 'CASH';
      _lastPurchase = null;
      _customerDues = null;
      _lastPurchaseCheckedFor = '';
    });
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale parked. Serve the next customer — resume it from "Held" when ready.')));
  }

  void _resumeHeld(_HeldSale h) {
    if (_cart.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Finish or park the current bill before resuming another.')));
      return;
    }
    setState(() {
      _held.remove(h);
      _cart.addAll(h.cart);
      _customerNameCtrl.text = h.customerName;
      _customerMobileCtrl.text = h.customerMobile;
      _prescriberCtrl.text = h.prescriber;
      _payment = h.payment;
      _showCustomer = true;
    });
    Navigator.pop(context);
  }

  void _showHeldSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheetState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Held sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_held.isEmpty)
              const Text('Nothing parked right now.', style: TextStyle(color: SevaCareColors.textMuted)),
            for (final h in List.of(_held))
              GlassCard(
                borderWidth: 0.8,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.customerName.isEmpty ? '${h.cart.length} item${h.cart.length == 1 ? '' : 's'}' : h.customerName,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('parked ${TimeOfDay.fromDateTime(h.heldAt).format(context)}',
                          style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () { _resumeHeld(h); setSheetState(() {}); },
                    child: const Text('Resume'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setSheetState(() => setState(() => _held.remove(h))),
                  ),
                ]),
              ),
          ]),
        );
      }),
    );
  }

  Future<void> _openWaLink(String link) async {
    final uri = Uri.parse(link);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')));
      }
    }
  }

  Future<void> _showReceipt(SaleReceipt r) async {
    final shop = ref.read(authProvider).capabilities?.tenantName ?? 'Pharmacy';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.check_circle, color: SevaCareColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text('Sold · ${r.invoiceNo}')),
        ]),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in r.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      _MedBadge(dosageForm: null, baseUnit: null, size: 26),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${l.brandName}  ×${l.qtyBaseUnits}')),
                      Text(_rupees(l.grossPaise)),
                    ]),
                  ),
                const Divider(),
                _receiptRow('Taxable', _rupees(r.taxablePaise)),
                _receiptRow('GST', _rupees(r.gstPaise)),
                _receiptRow('Total', _rupees(r.totalPaise), bold: true),
                _receiptRow('Paid via', r.paymentMode),
                if (r.warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final w in r.warnings)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SevaCareColors.peachSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline, size: 16, color: SevaCareColors.peachForeground),
                        const SizedBox(width: 6),
                        Expanded(child: Text(w, style: const TextStyle(fontSize: 12, color: SevaCareColors.peachForeground))),
                      ]),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (r.waLink != null)
            TextButton.icon(
              icon: const FaIcon(FontAwesomeIcons.whatsapp, size: 18, color: Color(0xFF25D366)),
              label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
              onPressed: () => _openWaLink(r.waLink!),
            ),
          TextButton.icon(
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download'),
            onPressed: () => PharmacyReceiptPdf.downloadReceipt(shopName: shop, receipt: r),
          ),
          TextButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Print'),
            onPressed: () => PharmacyReceiptPdf.printReceipt(shopName: shop, receipt: r),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  Widget _receiptRow(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: TextStyle(color: SevaCareColors.textMuted, fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(v, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // A shop laptop can hold the whole checkout beside the bill. A phone
      // cannot: the customer form, payment picker, totals and buttons stacked
      // under the cart ran past the bottom of the screen and took the Complete
      // Sale button with them. So on anything narrower, the bill keeps the
      // screen and checkout becomes a fixed bar that opens the review sheet.
      final wide = constraints.maxWidth >= 900;
      if (wide) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              _searchArea(),
              const Divider(height: 1),
              Expanded(child: _cartList()),
              if (_showFrequentStrip) ...[
                const Divider(height: 1),
                _frequentStrip(),
              ],
            ]),
          ),
          Container(width: 1, color: SevaCareColors.border),
          SizedBox(
            width: 380,
            child: SingleChildScrollView(child: _checkoutPanel()),
          ),
        ]);
      }
      return Column(children: [
        _searchArea(),
        const Divider(height: 1),
        Expanded(child: _cartList()),
        if (_showFrequentStrip) ...[
          const Divider(height: 1),
          _frequentStrip(),
        ],
        if (_cart.isNotEmpty) _compactCheckoutBar(),
      ]);
    });
  }

  /// The phone's checkout: a fixed two-line bar that can never be pushed off
  /// the screen, however long the bill or however small the device. Everything
  /// else — customer, prescriber, payment, totals — lives one tap away in the
  /// review sheet, which is where a pharmacist should be looking anyway before
  /// money changes hands.
  Widget _compactCheckoutBar() {
    final name = _customerNameCtrl.text.trim();
    final mobile = _customerMobileCtrl.text.trim();
    final who = name.isNotEmpty
        ? name
        : (mobile.isNotEmpty ? mobile : 'Add customer (optional)');
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: SevaCareColors.surface,
          border: Border(top: BorderSide(color: SevaCareColors.border)),
          boxShadow: [
            BoxShadow(
              color: SevaCareColors.shadowColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(
              child: InkWell(
                onTap: _openCustomerSheet,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(
                      _customerDues != null ? Icons.menu_book_outlined : Icons.person_outline,
                      size: 16,
                      color: _customerDues != null ? SevaCareColors.warning : SevaCareColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _customerDues != null
                            ? '$who · owes ${_rupees(_customerDues!.outstandingPaise)}'
                            : who,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _customerDues != null ? SevaCareColors.warning : SevaCareColors.textMuted,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(_rupees(_subtotalPaise),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            OutlinedButton(
              onPressed: _submitting ? null : _parkSale,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                minimumSize: const Size(0, 44),
              ),
              child: const Icon(Icons.pause_circle_outline, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GradientButton(
                label: 'Review & Pay · ${_cart.length} item${_cart.length == 1 ? '' : 's'}',
                icon: Icons.receipt_long_outlined,
                fullWidth: true,
                isLoading: _submitting,
                onPressed: _submitting ? null : _openReview,
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  /// Who is buying — kept out of the bill's way on a phone, but one tap from
  /// it, because the mobile number is what surfaces the khata balance and the
  /// "same as last time" repeat.
  void _openCustomerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              const Text('Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Optional — but a mobile number is what puts this bill on their khata '
                  'and lets you repeat their last purchase.',
                  style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
              const SizedBox(height: 14),
              AppFormField(
                label: 'Name',
                controller: _customerNameCtrl,
                autofocus: true,
                placeholder: 'Customer name',
                onChanged: (_) { setState(() {}); setSheet(() {}); },
              ),
              const SizedBox(height: 10),
              AppFormField(
                label: 'Mobile',
                controller: _customerMobileCtrl,
                keyboardType: TextInputType.phone,
                placeholder: '10-digit mobile',
                inputFormatters: [MobileInputFormatter()],
                onChanged: (v) async {
                  await _onCustomerMobileChanged(v);
                  if (ctx.mounted) setSheet(() {});
                },
              ),
              if (_customerDues != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SevaCareColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.menu_book_outlined, size: 15, color: SevaCareColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Already owes ${_rupees(_customerDues!.outstandingPaise)} on khata',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SevaCareColors.warning)),
                    ),
                  ]),
                ),
              ],
              if (_lastPurchase != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.replay, size: 16, color: SevaCareColors.primary),
                    label: Text('Same as last time · ${_rupees(_lastPurchase!.totalPaise)}'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _rebillLast();
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GradientButton(
                label: 'Done',
                icon: Icons.check,
                fullWidth: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
          ),
        );
      }),
    );
  }

  /// Nothing is dispensed until the pharmacist has seen the bill. The sheet is
  /// the last stop: lines, the GST split, what is missing (a prescriber for a
  /// Schedule H item, a mobile for a credit sale), and the cash to hand back.
  Future<void> _openReview() async {
    if (_cart.isEmpty) return;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ConfirmSaleSheet(
        cart: List.of(_cart),
        payment: _payment,
        customerName: _customerNameCtrl.text.trim(),
        customerMobile: _customerMobileCtrl.text.trim(),
        prescriberCtrl: _prescriberCtrl,
        duesPaise: _customerDues?.outstandingPaise,
        onEditCustomer: _openCustomerSheet,
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _payment = chosen);
    await _completeSale();
  }

  /// The frequent-chips shortcut stays visible while a bill is being built —
  /// regulars often buy several of the usual items, so picking one must not
  /// hide the rest. It's a single compact scrollable line below the cart, and
  /// only yields during an active search (results overlay the same space).
  bool get _showFrequentStrip =>
      _searchCtrl.text.trim().isEmpty && _frequent.isNotEmpty;

  Widget _searchArea() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AppFormField(
          label: 'Find a medicine',
          controller: _searchCtrl,
          placeholder: _loadingCatalog ? 'Loading catalog…' : 'Type 3 letters — e.g. “dol”, “aug”…',
          onChanged: _search,
          suffixIcon: _loadingCatalog
              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
              : const Icon(Icons.search),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (_held.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                avatar: const Icon(Icons.pause_circle_outline, size: 16, color: SevaCareColors.warning),
                label: Text('Held (${_held.length})'),
                onPressed: _showHeldSheet,
              ),
            ),
          TextButton.icon(
            onPressed: _addOthers,
            icon: const Icon(Icons.add_circle_outline, size: 16),
            label: const Text('Others'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
          ),
        ]),
      ),
      if (_results.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          decoration: BoxDecoration(
            color: SevaCareColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SevaCareColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _results.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) => _resultTile(_results[i]),
          ),
        ),
    ]);
  }

  Widget _resultTile(PharmacySku s) {
    final remaining = _remaining(s);
    final out = remaining <= 0;
    return ListTile(
      dense: true,
      leading: _MedBadge(dosageForm: s.dosageForm, baseUnit: s.baseUnit, size: 34),
      title: Text(s.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([s.strength, s.dosageForm, if (s.isPrescriptionOnly) 'Rx ${s.scheduleClass}']
          .where((e) => e != null && e.toString().isNotEmpty).join(' · ')),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (s.mrpPaise > 0) Text(_rupees(s.mrpPaise), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(out ? 'out of stock' : '$remaining in stock',
              style: TextStyle(fontSize: 11, color: out ? SevaCareColors.error : SevaCareColors.textMuted)),
        ]),
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 16, color: SevaCareColors.textMuted),
          tooltip: 'Edit GST / details',
          padding: const EdgeInsets.all(6),
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          visualDensity: VisualDensity.compact,
          onPressed: () => _openEditSku(s),
        ),
      ]),
      onTap: () => _addToCart(s),
    );
  }

  void _openEditSku(PharmacySku s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditSkuSheet(
        skuPublicId: s.skuPublicId,
        brandName: s.brandName,
        prefill: s,
        onSaved: (updated) {
          // Merge into the cached catalog so the next line prices with the new
          // GST — but keep the live on-hand/MRP the update response can't know.
          final cached = _catalog[s.skuPublicId];
          if (cached != null) {
            setState(() {
              _catalog[s.skuPublicId] = PharmacySku(
                skuPublicId: cached.skuPublicId,
                brandName: cached.brandName,
                manufacturer: cached.manufacturer,
                strength: cached.strength,
                dosageForm: cached.dosageForm,
                baseUnit: cached.baseUnit,
                scheduleClass: updated.scheduleClass,
                gstRateBp: updated.gstRateBp,
                rackLocation: updated.rackLocation,
                qtyOnHand: cached.qtyOnHand,
                mrpPaise: cached.mrpPaise,
              );
            });
          }
        },
      ),
    );
  }

  /// One compact, horizontally-scrollable line of pills — never taller than a
  /// row, so it fits mobile without pushing the bill around.
  Widget _frequentStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
      child: Row(children: [
        const Icon(Icons.bolt, size: 14, color: SevaCareColors.warning),
        const SizedBox(width: 4),
        Expanded(
          child: SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 16),
              itemCount: _frequent.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => _frequentPill(_frequent[i]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _frequentPill(TopMedicine t) {
    final style = _medStyleOf(t.dosageForm, null);
    return InkWell(
      onTap: () => _addFrequent(t),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: SevaCareColors.surfaceMuted,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SevaCareColors.border, width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(t.brandName,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _cartList() {
    if (_cart.isEmpty) {
      return const _InvoicesTable();
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      itemCount: _cart.length,
      itemBuilder: (_, i) => _cartTile(_cart[i]),
    );
  }

  Widget _cartTile(_CartLine line) {
    if (line.isManual) {
      return GlassCard(
        borderWidth: 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: SevaCareColors.textMuted.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined, size: 20, color: SevaCareColors.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(line.manualLabel!, style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('Manual charge · not a medicine',
                  style: TextStyle(fontSize: 11, color: SevaCareColors.textMuted)),
            ]),
          ),
          Text(_rupees(line.lineTotalPaise), style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: SevaCareColors.textMuted),
            onPressed: () => setState(() => _cart.remove(line)),
          ),
        ]),
      );
    }
    final sku = line.sku!;
    final remaining = _remaining(sku);
    final short = sku.qtyOnHand > 0 && remaining < 0;
    final noStock = sku.qtyOnHand <= 0;
    return GlassCard(
      borderWidth: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(children: [
        _MedBadge(dosageForm: sku.dosageForm, baseUnit: sku.baseUnit),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sku.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              sku.mrpPaise > 0
                  ? '${_rupees(sku.mrpPaise)} / ${sku.baseUnit.toLowerCase()} · ${_rupees(line.lineTotalPaise)}'
                  : 'MRP set at billing · ${sku.baseUnit.toLowerCase()}',
              style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted),
            ),
            Text(
              noStock
                  ? 'no stock recorded'
                  : short
                      ? '${remaining.abs()} beyond stock'
                      : '$remaining left',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (noStock || short)
                    ? SevaCareColors.error
                    : (remaining <= 5 ? SevaCareColors.warning : SevaCareColors.success),
              ),
            ),
          ]),
        ),
        _stepper(line),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: SevaCareColors.textMuted),
          onPressed: () => setState(() => _cart.remove(line)),
        ),
      ]),
    );
  }

  Widget _stepper(_CartLine line) => Row(children: [
        _roundBtn(Icons.remove, () => setState(() {
              if (line.qty > 1) line.qty -= 1;
            })),
        InkWell(
          onTap: () => _editQty(line),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
        _roundBtn(Icons.add, () => setState(() => line.qty += 1)),
      ]);

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: SevaCareColors.primarySoft, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 18, color: SevaCareColors.primary),
        ),
      );

  Widget _checkoutPanel() {
    final disabled = _cart.isEmpty || _submitting;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        border: Border(top: BorderSide(color: SevaCareColors.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Customer (optional but encouraged) — name + mobile is enough.
        InkWell(
          onTap: () => setState(() => _showCustomer = !_showCustomer),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.person_outline, size: 18, color: SevaCareColors.textMuted),
              const SizedBox(width: 8),
              Text(
                _customerNameCtrl.text.trim().isEmpty
                    ? 'Add customer (optional)'
                    : _customerNameCtrl.text.trim(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Icon(_showCustomer ? Icons.expand_less : Icons.expand_more, color: SevaCareColors.textMuted),
            ]),
          ),
        ),
        if (_showCustomer) ...[
          const SizedBox(height: 6),
          AppFormField(label: 'Name', controller: _customerNameCtrl, placeholder: 'Customer name',
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          AppFormField(
            label: 'Mobile', controller: _customerMobileCtrl, keyboardType: TextInputType.phone,
            placeholder: '10-digit mobile', inputFormatters: [MobileInputFormatter()],
            onChanged: _onCustomerMobileChanged,
          ),
          if (_customerDues != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SevaCareColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.menu_book_outlined, size: 14, color: SevaCareColors.warning),
                const SizedBox(width: 6),
                Text('Owes ${_rupees(_customerDues!.outstandingPaise)} on khata',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SevaCareColors.warning)),
              ]),
            ),
          ],
          if (_lastPurchase != null) ...[
            const SizedBox(height: 6),
            _rebillChip(),
          ],
          const SizedBox(height: 8),
        ],
        if (_cart.any((c) => c.sku?.isPrescriptionOnly ?? false))
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: AppFormField(
              label: 'Prescriber (Schedule H item in cart)',
              controller: _prescriberCtrl,
              placeholder: 'Doctor name on the prescription',
              onChanged: (_) => setState(() {}),
            ),
          ),
        const SizedBox(height: 8),
        _paymentPicker(),
        const SizedBox(height: 12),
        if (_subtotalPaise > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Subtotal (MRP incl. GST)', style: TextStyle(color: SevaCareColors.textMuted)),
              Text(_rupees(_subtotalPaise), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            ]),
          ),
        Row(children: [
          if (_cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.pause_circle_outline, size: 18),
                label: const Text('Park'),
                onPressed: _submitting ? null : _parkSale,
              ),
            ),
          Expanded(
            child: GradientButton(
              label: 'Review & Pay · ${_cart.length} item${_cart.length == 1 ? '' : 's'}',
              icon: Icons.receipt_long_outlined,
              fullWidth: true,
              isLoading: _submitting,
              onPressed: disabled ? null : _openReview,
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _paymentPicker() {
    return _PaymentModeChips(
      codes: const ['CASH', 'UPI', 'CARD', 'CREDIT'],
      selected: _payment,
      onChanged: (v) => setState(() => _payment = v),
    );
  }
}

/// The bill, before it becomes one. A counter sale is irreversible in every way
/// that matters — stock leaves the shelf, a GST invoice number is burned, and
/// undoing it means a void and a refund — so it gets a deliberate second look
/// rather than firing on the tap that added the last item.
///
/// It is also where a pharmacist's checks belong, not a receipt printed after
/// the fact: a Schedule H item with no prescriber recorded, a quantity larger
/// than what is on the shelf, a credit sale with no mobile to put the khata
/// against. And the change to hand back, because arithmetic at a busy counter
/// is where money actually goes missing.
class _ConfirmSaleSheet extends StatefulWidget {
  final List<_CartLine> cart;
  final String payment;
  final String customerName;
  final String customerMobile;
  final TextEditingController prescriberCtrl;
  final int? duesPaise;
  final VoidCallback onEditCustomer;

  const _ConfirmSaleSheet({
    required this.cart,
    required this.payment,
    required this.customerName,
    required this.customerMobile,
    required this.prescriberCtrl,
    required this.onEditCustomer,
    this.duesPaise,
  });

  @override
  State<_ConfirmSaleSheet> createState() => _ConfirmSaleSheetState();
}

class _ConfirmSaleSheetState extends State<_ConfirmSaleSheet> {
  late String _payment = widget.payment;
  final _tenderedCtrl = TextEditingController();

  @override
  void dispose() {
    _tenderedCtrl.dispose();
    super.dispose();
  }

  int get _total => widget.cart.fold(0, (s, c) => s + c.lineTotalPaise);

  /// The same MRP-inclusive extraction the server bills with, mirrored here so
  /// the pharmacist sees the split *before* confirming. The receipt remains
  /// authoritative; this is a preview, and per-line rounding may move a paisa.
  (int taxable, int gst) get _split {
    var taxable = 0, gst = 0;
    for (final c in widget.cart) {
      final gross = c.lineTotalPaise;
      final bp = c.sku?.gstRateBp ?? 0;
      final t = gross * 10000 ~/ (10000 + bp);
      taxable += t;
      gst += gross - t;
    }
    return (taxable, gst);
  }

  bool get _hasRx => widget.cart.any((c) => c.sku?.isPrescriptionOnly ?? false);
  bool get _missingPrescriber => _hasRx && widget.prescriberCtrl.text.trim().isEmpty;

  List<_CartLine> get _overStock =>
      widget.cart.where((c) => !c.isManual && c.qty > c.sku!.qtyOnHand).toList();

  bool get _creditWithoutMobile => _payment == 'CREDIT' && widget.customerMobile.trim().isEmpty;

  int? get _tenderedPaise {
    final v = double.tryParse(_tenderedCtrl.text.trim());
    return v == null ? null : (v * 100).round();
  }

  /// Round the total up to the next note a customer actually hands over.
  List<int> get _tenderSuggestions {
    final t = _total;
    final out = <int>{t};
    for (final note in [5000, 10000, 20000, 50000, 100000]) {
      if (note >= t) out.add(note);
      final rounded = ((t + note - 1) ~/ note) * note;
      if (rounded > t) out.add(rounded);
    }
    final list = out.toList()..sort();
    return list.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final (taxable, gst) = _split;
    final tendered = _tenderedPaise;
    final change = tendered == null ? null : tendered - _total;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(
                child: Text('Review the bill', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Text('${widget.cart.length} item${widget.cart.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            ]),
            const SizedBox(height: 10),

            // ── Customer ───────────────────────────────────────────────────
            InkWell(
              onTap: () { Navigator.pop(context); widget.onEditCustomer(); },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: SevaCareColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 16, color: SevaCareColors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.customerName.isEmpty && widget.customerMobile.isEmpty
                          ? 'Walk-in customer'
                          : [widget.customerName, widget.customerMobile].where((e) => e.isNotEmpty).join(' · '),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Text('Change', style: TextStyle(fontSize: 12, color: SevaCareColors.primary)),
                ]),
              ),
            ),
            const SizedBox(height: 12),

            // ── Lines ──────────────────────────────────────────────────────
            for (final c in widget.cart) _lineRow(c),
            const Divider(height: 20),

            // ── Totals ─────────────────────────────────────────────────────
            _totalRow('Taxable value', _rupees(taxable)),
            _totalRow('GST (already inside MRP)', _rupees(gst)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total payable', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(_rupees(_total),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: SevaCareColors.primary)),
            ]),
            const SizedBox(height: 14),

            // ── Warnings ───────────────────────────────────────────────────
            if (_missingPrescriber)
              _warn(
                Icons.gpp_maybe_outlined,
                SevaCareColors.error,
                'Schedule H item without a prescriber',
                'The law wants the prescribing doctor on record for '
                    '${widget.cart.where((c) => c.sku?.isPrescriptionOnly ?? false).map((c) => c.sku!.brandName).join(', ')}. '
                    'Type the name below — or sell without it, knowingly.',
              ),
            if (_hasRx) ...[
              const SizedBox(height: 8),
              AppFormField(
                label: 'Prescriber',
                controller: widget.prescriberCtrl,
                placeholder: 'Doctor named on the prescription',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
            ],
            for (final c in _overStock)
              _warn(
                Icons.inventory_2_outlined,
                SevaCareColors.warning,
                'More ${c.sku!.brandName} than the shelf shows',
                'Selling ${c.qty} with ${c.sku!.qtyOnHand} on record. If the stock is really there, '
                    'a delivery was never entered — receive it, or the ledger stays wrong.',
              ),
            if (_creditWithoutMobile)
              _warn(
                Icons.menu_book_outlined,
                SevaCareColors.warning,
                'Credit sale with no mobile number',
                'A khata needs someone to chase. Without a mobile this debt is not tracked anywhere.',
              ),
            if (widget.duesPaise != null && widget.duesPaise! > 0)
              _warn(
                Icons.account_balance_wallet_outlined,
                SevaCareColors.warning,
                'This customer already owes ${_rupees(widget.duesPaise!)}',
                'Consider collecting it before extending more credit.',
              ),

            // ── Payment ────────────────────────────────────────────────────
            const SizedBox(height: 6),
            const Text('Paid by', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            _PaymentModeChips(
              codes: const ['CASH', 'UPI', 'CARD', 'CREDIT'],
              selected: _payment,
              onChanged: (v) => setState(() => _payment = v),
            ),

            // ── Cash tendered → change ─────────────────────────────────────
            if (_payment == 'CASH') ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: AppFormField(
                    label: 'Cash given (optional)',
                    controller: _tenderedCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    placeholder: '₹ handed over',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Change to return',
                        style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
                    const SizedBox(height: 8),
                    Text(
                      change == null ? '—' : (change < 0 ? 'short ${_rupees(-change)}' : _rupees(change)),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: change == null
                            ? SevaCareColors.textMuted
                            : (change < 0 ? SevaCareColors.error : SevaCareColors.success),
                      ),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final t in _tenderSuggestions)
                  ActionChip(
                    label: Text(_rupees(t), style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(
                        () => _tenderedCtrl.text = (t / 100).toStringAsFixed(2)),
                  ),
              ]),
            ],

            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Back', maxLines: 1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: GradientButton(
                  label: 'Complete Sale · ${_rupees(_total)}',
                  icon: Icons.check_circle_outline,
                  fullWidth: true,
                  onPressed: () => Navigator.pop(context, _payment),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _lineRow(_CartLine c) {
    final rx = c.sku?.isPrescriptionOnly ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        _MedBadge(dosageForm: c.sku?.dosageForm, baseUnit: c.sku?.baseUnit, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(c.isManual ? c.manualLabel! : c.sku!.brandName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
              if (rx) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: SevaCareColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text('Rx',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: SevaCareColors.error)),
                ),
              ],
            ]),
            Text(
              c.isManual
                  ? 'Manual charge'
                  : '${c.qty} × ${_rupees(c.sku!.mrpPaise)} / ${c.sku!.baseUnit.toLowerCase()}',
              style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted),
            ),
          ]),
        ),
        Text(_rupees(c.lineTotalPaise), style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _totalRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: SevaCareColors.textMuted, fontSize: 13)),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      );

  Widget _warn(IconData icon, Color c, String title, String body) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
            ]),
          ),
        ]),
      );
}

/// Every bill in a date range — a real data table instead of a plain list, so
/// the owner can sort by amount or date and act on a bill (refund, share,
/// download, void) without hunting for it. Sits where the cart is when the
/// cart is empty: the counter's idle state is "what happened", not a blank
/// screen.
class _InvoicesTable extends ConsumerStatefulWidget {
  const _InvoicesTable();
  @override
  ConsumerState<_InvoicesTable> createState() => _InvoicesTableState();
}

class _InvoicesTableState extends ConsumerState<_InvoicesTable> {
  /// Ten bills is what a counter can actually scan without scrolling past the
  /// one it wants; the rest are a page turn away rather than an endless list.
  static const _pageSize = 10;

  DateTimeRange _range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 6)), end: DateTime.now());
  String _sortBy = 'date';
  List<SaleSummary> _sales = [];
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int get _pageCount => _sales.isEmpty ? 1 : ((_sales.length - 1) ~/ _pageSize) + 1;

  List<SaleSummary> get _pageSales {
    final start = _page * _pageSize;
    if (start >= _sales.length) return const [];
    return _sales.sublist(start, (start + _pageSize).clamp(0, _sales.length));
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    setState(() => _loading = true);
    try {
      final list = await ref.read(repositoryProvider).salesInRange(
          auth.tenantPublicId!, auth.token!, _iso(_range.start), _iso(_range.end), sortBy: _sortBy);
      if (mounted) setState(() { _sales = list; _page = 0; });
    } catch (_) {
      if (mounted) setState(() { _sales = []; _page = 0; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  Future<SaleReceipt?> _fetchReceipt(SaleSummary s) async {
    final auth = ref.read(authProvider);
    try {
      return await ref.read(repositoryProvider).getReceipt(auth.tenantPublicId!, auth.token!, s.salePublicId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
      return null;
    }
  }

  Future<void> _openDetail(SaleSummary s) async {
    final receipt = await _fetchReceipt(s);
    if (receipt == null || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _InvoiceDetailSheet(sale: s, receipt: receipt, onChanged: _load),
    );
  }

  void _refund(SaleSummary s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReturnSheet(sale: s, onDone: _load),
    );
  }

  Future<void> _share(SaleSummary s) async {
    final receipt = await _fetchReceipt(s);
    if (receipt == null || !mounted) return;
    if (receipt.waLink != null) {
      final uri = Uri.parse(receipt.waLink!);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No customer mobile on this bill to share to.')));
    }
  }

  Future<void> _download(SaleSummary s) async {
    final receipt = await _fetchReceipt(s);
    if (receipt == null) return;
    final shop = ref.read(authProvider).capabilities?.tenantName ?? 'Pharmacy';
    await PharmacyReceiptPdf.downloadReceipt(shopName: shop, receipt: receipt);
  }

  Future<void> _confirmVoid(SaleSummary s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text('Void ${s.invoiceNo}?', style: const TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'This reverses the stock this sale drew — every unit goes back on the shelf — '
          'and marks the bill VOID. It stays on the record, but no longer counts toward '
          'takings. This cannot be undone from here.',
          style: TextStyle(color: SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SevaCareColors.error),
            child: const Text('Void Sale'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final auth = ref.read(authProvider);
    try {
      await ref.read(repositoryProvider).voidSale(auth.tenantPublicId!, auth.token!, s.salePublicId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Icon(Icons.search, size: 15, color: SevaCareColors.textMuted),
              SizedBox(width: 6),
              Expanded(
                child: Text('Find a medicine above to start a bill.',
                    style: TextStyle(fontSize: 12.5, color: SevaCareColors.textMuted)),
              ),
            ]),
          ),
          _Accordion(
            title: 'Recent Invoices',
            icon: Icons.receipt_long_outlined,
            color: SevaCareColors.primary,
            subtitle: '${_iso(_range.start)} → ${_iso(_range.end)}',
            count: _sales.length,
            child: _invoicesBody(),
          ),
        ],
      ),
    );
  }

  Widget _invoicesBody() {
    if (_loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
    }
    if (_sales.isEmpty) {
      return Column(children: [
        _toolbar(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(children: [
            Icon(Icons.receipt_long_outlined, size: 42, color: SevaCareColors.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 10),
            const Text('No bills in this date range.', style: TextStyle(color: SevaCareColors.textMuted)),
          ]),
        ),
      ]);
    }
    final page = _pageSales;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _toolbar(),
      const SizedBox(height: 4),
      for (var i = 0; i < page.length; i++) _invoiceRow(page[i], i),
      const SizedBox(height: 8),
      _pager(),
    ]);
  }

  Widget _toolbar() => Row(children: [
        InkWell(
          onTap: _pickRange,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.date_range, size: 14, color: SevaCareColors.textMuted),
              const SizedBox(width: 4),
              const Text('Date range',
                  style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            ]),
          ),
        ),
        const Spacer(),
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort, size: 18, color: SevaCareColors.textMuted),
          tooltip: 'Sort',
          initialValue: _sortBy,
          onSelected: (v) { setState(() => _sortBy = v); _load(); },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'date', child: Text('Newest first')),
            PopupMenuItem(value: 'amount', child: Text('Largest amount first')),
          ],
        ),
      ]);

  /// One bill, one row — and a single ⋮ instead of four icons, so the row stays
  /// short enough to read on a phone and wide enough to tap. Alternating tints
  /// make the rows read as a list of *things you can open*, not a wall of text.
  Widget _invoiceRow(SaleSummary s, int indexOnPage) {
    final striped = indexOnPage.isOdd;
    final who = [
      if ((s.customerName ?? '').isNotEmpty) s.customerName!,
    ].join();
    return Material(
      color: s.isVoid
          ? SevaCareColors.error.withValues(alpha: 0.05)
          : (striped ? SevaCareColors.surfaceMuted.withValues(alpha: 0.55) : Colors.transparent),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _openDetail(s),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: Text(s.invoiceNo,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ),
                  if (s.isVoid) ...[const SizedBox(width: 6), _voidBadge()],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(
                    child: Text(
                      '${(s.soldAt ?? '').split('T').first} · ${s.itemCount} item${s.itemCount == 1 ? '' : 's'} · '
                      '${s.paymentMode}${who.isNotEmpty ? ' · $who' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted),
                    ),
                  ),
                  if ((s.customerMobile ?? '').isNotEmpty) ...[
                    const Text(' · ', style: TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                    MaskedText(s.customerMobile!,
                        style: const TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
                  ],
                ]),
              ]),
            ),
            const SizedBox(width: 8),
            Text(_rupees(s.totalPaise), style: const TextStyle(fontWeight: FontWeight.w700)),
            _actionMenu(s),
          ]),
        ),
      ),
    );
  }

  Widget _pager() {
    final from = _page * _pageSize + 1;
    final to = (from + _pageSize - 1).clamp(from, _sales.length);
    return Row(children: [
      Text('$from–$to of ${_sales.length}',
          style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
      const Spacer(),
      IconButton(
        icon: const Icon(Icons.chevron_left, size: 20),
        tooltip: 'Previous 10',
        onPressed: _page == 0 ? null : () => setState(() => _page -= 1),
      ),
      Text('${_page + 1} / $_pageCount',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      IconButton(
        icon: const Icon(Icons.chevron_right, size: 20),
        tooltip: 'Next 10',
        onPressed: _page >= _pageCount - 1 ? null : () => setState(() => _page += 1),
      ),
    ]);
  }

  Widget _voidBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: SevaCareColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: const Text('VOID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SevaCareColors.error)),
      );

  /// Everything a bill can have done to it, behind one ⋮. Four icons per row
  /// crowded a phone and still had to be tapped precisely; a menu is one big
  /// target on a phone, a tablet and a mouse alike, and it can afford words —
  /// "Void" beside a trash can is far less ambiguous than the can alone.
  Widget _actionMenu(SaleSummary s) => PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18, color: SevaCareColors.textMuted),
        tooltip: 'Bill actions',
        onSelected: (v) {
          switch (v) {
            case 'open':
              _openDetail(s);
            case 'refund':
              _refund(s);
            case 'whatsapp':
              _share(s);
            case 'download':
              _download(s);
            case 'void':
              _confirmVoid(s);
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'open',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.visibility_outlined, size: 18),
              title: Text('View bill'),
            ),
          ),
          PopupMenuItem(
            value: 'refund',
            enabled: !s.isVoid,
            child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.keyboard_return, size: 18),
              title: Text('Refund items'),
            ),
          ),
          const PopupMenuItem(
            value: 'whatsapp',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(FontAwesomeIcons.whatsapp, size: 17, color: Color(0xFF25D366)),
              title: Text('Send on WhatsApp'),
            ),
          ),
          const PopupMenuItem(
            value: 'download',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.download_outlined, size: 18),
              title: Text('Download PDF'),
            ),
          ),
          PopupMenuItem(
            value: 'void',
            enabled: !s.isVoid,
            child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_outline, size: 18, color: SevaCareColors.error),
              title: Text('Void this bill', style: TextStyle(color: SevaCareColors.error)),
            ),
          ),
        ],
      );
}

/// The full bill, reopened — every line, any refund it already carries, and
/// the same actions the table row offers, for when a glance isn't enough.
class _InvoiceDetailSheet extends ConsumerWidget {
  final SaleSummary sale;
  final SaleReceipt receipt;
  final VoidCallback onChanged;
  const _InvoiceDetailSheet({required this.sale, required this.receipt, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Row(children: [
            Text('Invoice ${receipt.invoiceNo}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (sale.isVoid) ...[const SizedBox(width: 8), _staticVoidBadge()],
          ]),
          if (receipt.customerName != null || receipt.customerMobile != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (receipt.customerName != null && receipt.customerName!.isNotEmpty)
                  Text(
                      '${receipt.customerName}${receipt.customerMobile != null && receipt.customerMobile!.isNotEmpty ? ' · ' : ''}',
                      style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
                if (receipt.customerMobile != null && receipt.customerMobile!.isNotEmpty)
                  MaskedText(receipt.customerMobile!,
                      style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
              ]),
            ),
          const SizedBox(height: 12),
          for (final l in receipt.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text('${l.qtyBaseUnits} × ${l.brandName}')),
                Text(_rupees(l.grossPaise)),
              ]),
            ),
          const Divider(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(_rupees(receipt.totalPaise), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        ]),
      ),
    );
  }

  Widget _staticVoidBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: SevaCareColors.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
        child: const Text('VOID', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: SevaCareColors.error)),
      );
}

// ── Stock ───────────────────────────────────────────────────────────────────

class _StockTab extends ConsumerStatefulWidget {
  const _StockTab();
  @override
  ConsumerState<_StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<_StockTab> {
  List<NearExpiryBatch> _nearExpiry = [];
  List<LowStockItem> _lowStock = [];
  List<GrnSummary> _recentGrns = [];
  bool _loading = true;

  // Bulk refill selection: key -> (brand name, suggested reorder qty).
  final Map<String, (String, int)> _refillSelection = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    setState(() => _loading = true);
    try {
      final ne = await ref.read(repositoryProvider).nearExpiry(auth.tenantPublicId!, auth.token!);
      final ls = await ref.read(repositoryProvider).lowStock(auth.tenantPublicId!, auth.token!);
      final gr = await ref.read(repositoryProvider).recentGrns(auth.tenantPublicId!, auth.token!, limit: 5);
      if (mounted) setState(() { _nearExpiry = ne; _lowStock = ls; _recentGrns = gr; });
    } catch (_) {/* show empty */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          GradientButton(
            label: 'Receive Delivery',
            icon: Icons.local_shipping_outlined,
            fullWidth: true,
            onPressed: () => _openReceiveSheet(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: const Text('Import medicines from CSV / Excel'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: _openImportSheet,
          ),
          const SizedBox(height: 20),
          if (_refillSelection.isNotEmpty) ...[
            _refillBar(),
            const SizedBox(height: 12),
          ],
          // Expiry is the one thing a pharmacist must not have to go looking
          // for — an expired strip on the shelf is a patient-safety problem, so
          // this section opens itself. The rest are reference, and stay shut
          // until asked for.
          _Accordion(
            title: 'Expiring soon',
            icon: Icons.schedule,
            color: SevaCareColors.warning,
            subtitle: 'Next 90 days — sell or return these first',
            count: _nearExpiry.length,
            initiallyOpen: true,
            child: _loading
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                : _nearExpiry.isEmpty
                    ? _emptyNote('Nothing expiring in the next 90 days.')
                    : Column(children: [for (final b in _nearExpiry) _nearExpiryTile(b)]),
          ),
          _Accordion(
            title: 'Running low',
            icon: Icons.trending_down,
            color: SevaCareColors.error,
            subtitle: 'Below the reorder level you set',
            count: _lowStock.length,
            child: _loading
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                : _lowStock.isEmpty
                    ? _emptyNote('No tracked item is below its reorder level.')
                    : Column(children: [for (final l in _lowStock) _lowStockTile(l)]),
          ),
          _Accordion(
            title: 'Recent deliveries',
            icon: Icons.local_shipping_outlined,
            color: SevaCareColors.primary,
            subtitle: 'What came in, and from whom',
            count: _recentGrns.length,
            child: _loading
                ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                : _recentGrns.isEmpty
                    ? _emptyNote('No deliveries recorded yet.')
                    : Column(children: [for (final g in _recentGrns) _grnTile(g)]),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _grnTile(GrnSummary g) => GlassCard(
        borderWidth: 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(g.supplierName ?? g.grnPublicId, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${g.lineCount} item${g.lineCount == 1 ? '' : 's'} · ${g.totalQtyBase} units'
                '${g.supplierInvoiceNo != null ? ' · Inv ${g.supplierInvoiceNo}' : ''}',
                style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted),
              ),
            ]),
          ),
          if (g.totalCostPaise > 0)
            Text(_rupees(g.totalCostPaise), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _emptyNote(String s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(s, style: const TextStyle(color: SevaCareColors.textMuted)),
      );

  void _openEditSku(String skuPublicId, String brandName) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditSkuSheet(
        skuPublicId: skuPublicId,
        brandName: brandName,
        onSaved: (_) => _load(),
      ),
    );
  }

  Widget _nearExpiryTile(NearExpiryBatch b) {
    final key = 'exp:${b.skuPublicId}:${b.batchPublicId}';
    final selected = _refillSelection.containsKey(key);
    return GlassCard(
      borderWidth: 0.8,
      onTap: () => _openEditSku(b.skuPublicId, b.brandName),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Checkbox(
          value: selected,
          onChanged: (v) => setState(() {
            if (v == true) {
              _refillSelection[key] = (b.brandName, b.qtyOnHand > 0 ? b.qtyOnHand : 10);
            } else {
              _refillSelection.remove(key);
            }
          }),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Batch ${b.batchNo} · exp ${b.expiryDate ?? '—'}',
                style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          ]),
        ),
        _pill('${b.qtyOnHand} left', b.batchStatus == 'EXPIRED' ? SevaCareColors.error : SevaCareColors.warning),
      ]),
    );
  }

  Widget _lowStockTile(LowStockItem l) {
    final key = 'low:${l.skuPublicId}';
    final selected = _refillSelection.containsKey(key);
    final suggested = l.reorderQty ?? (l.reorderLevel * 2);
    return GlassCard(
      borderWidth: 0.8,
      onTap: () => _openEditSku(l.skuPublicId, l.brandName),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(children: [
        Checkbox(
          value: selected,
          onChanged: (v) => setState(() {
            if (v == true) {
              _refillSelection[key] = (l.brandName, suggested);
            } else {
              _refillSelection.remove(key);
            }
          }),
        ),
        Expanded(child: Text(l.brandName, style: const TextStyle(fontWeight: FontWeight.w600))),
        _pill('${l.qtyOnHand} / ${l.reorderLevel}', SevaCareColors.error),
      ]),
    );
  }

  Widget _refillBar() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: SevaCareColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SevaCareColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.local_shipping_outlined, size: 18, color: SevaCareColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${_refillSelection.length} item${_refillSelection.length == 1 ? '' : 's'} selected for refill',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          TextButton(onPressed: () => setState(_refillSelection.clear), child: const Text('Clear')),
          const SizedBox(width: 4),
          GradientButton(label: 'Request Refill', icon: Icons.send_outlined, onPressed: _openRefillSheet),
        ]),
      );

  void _openRefillSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _RefillRequestSheet(
        items: _refillSelection.values.toList(),
        onSent: () => setState(_refillSelection.clear),
      ),
    );
  }

  Widget _pill(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(s, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      );

  void _openReceiveSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReceiveStockSheet(onDone: _load),
    );
  }

  void _openImportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ImportCatalogSheet(onDone: _load),
    );
  }
}

/// Compose one bulk message for every selected medicine and hand it to the
/// device's own email or WhatsApp app — no backend send needed, the same
/// tap-to-open pattern the receipt share button already uses, so it works
/// today with no SMTP or WhatsApp-Business credentials configured.
class _RefillRequestSheet extends ConsumerStatefulWidget {
  final List<(String, int)> items; // (brandName, suggestedQty)
  final VoidCallback onSent;
  const _RefillRequestSheet({required this.items, required this.onSent});
  @override
  ConsumerState<_RefillRequestSheet> createState() => _RefillRequestSheetState();
}

class _RefillRequestSheetState extends ConsumerState<_RefillRequestSheet> {
  List<Supplier> _suppliers = [];
  String? _supplierId;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _mobileCtrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    try {
      final list = await ref.read(repositoryProvider).listSuppliers(auth.tenantPublicId!, auth.token!);
      if (mounted) {
        setState(() {
          _suppliers = list;
          if (list.length == 1) _pickSupplier(list.first.supplierPublicId);
        });
      }
    } catch (_) {/* empty dropdown, still usable */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickSupplier(String? id) {
    setState(() {
      _supplierId = id;
      final s = _suppliers.where((x) => x.supplierPublicId == id).firstOrNull;
      _emailCtrl.text = s?.email ?? '';
      _mobileCtrl.text = s?.mobileNumber ?? '';
    });
  }

  String get _message {
    final supplierName = _suppliers.where((s) => s.supplierPublicId == _supplierId).firstOrNull?.supplierName;
    final buf = StringBuffer();
    buf.writeln('Refill request${supplierName != null ? ' — $supplierName' : ''}');
    buf.writeln();
    for (final (brand, qty) in widget.items) {
      buf.writeln('- $brand — $qty units');
    }
    buf.writeln();
    buf.write('Please send at your earliest. Thank you.');
    return buf.toString();
  }

  Future<void> _sendEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the supplier\'s email first.')));
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent('Refill request')}&body=${Uri.encodeComponent(_message)}',
    );
    if (await launchUrl(uri)) widget.onSent();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendWhatsApp() async {
    final mobile = _mobileCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
    if (mobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the supplier\'s WhatsApp number first.')));
      return;
    }
    final withCountry = mobile.length == 10 ? '91$mobile' : mobile;
    final uri = Uri.parse('https://wa.me/$withCountry?text=${Uri.encodeComponent(_message)}');
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) widget.onSent();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Refill ${widget.items.length} item${widget.items.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Pick who this goes to, then send by email or WhatsApp.',
              style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_suppliers.isEmpty)
            const Text('No suppliers on file yet — add one from Receive Delivery first.',
                style: TextStyle(color: SevaCareColors.textMuted))
          else
            DropdownButtonFormField<String>(
              initialValue: _supplierId,
              decoration: const InputDecoration(labelText: 'Supplier', isDense: true),
              items: [
                for (final s in _suppliers)
                  DropdownMenuItem(value: s.supplierPublicId, child: Text(s.supplierName, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: _pickSupplier,
            ),
          const SizedBox(height: 10),
          AppFormField(label: 'Email', controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
              placeholder: 'supplier@example.com'),
          const SizedBox(height: 8),
          AppFormField(label: 'WhatsApp number', controller: _mobileCtrl, keyboardType: TextInputType.phone,
              placeholder: '10-digit mobile', inputFormatters: [MobileInputFormatter()]),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SevaCareColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
            child: Text(_message, style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.email_outlined, size: 18),
                label: const Text('Email'),
                onPressed: _sendEmail,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GradientButton(
                label: 'WhatsApp',
                icon: FontAwesomeIcons.whatsapp,
                onPressed: _sendWhatsApp,
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Corrections to a medicine after it's on the shelf — a GST rate change lands
/// in the market and the catalog must follow, an HSN gets fixed, a rack moves.
/// Blank fields are left untouched, so the sheet is safe to open from places
/// that don't know the current values (the stock tab's alert tiles).
class _EditSkuSheet extends ConsumerStatefulWidget {
  final String skuPublicId;
  final String brandName;
  final PharmacySku? prefill;
  final void Function(PharmacySku updated)? onSaved;
  const _EditSkuSheet({required this.skuPublicId, required this.brandName, this.prefill, this.onSaved});
  @override
  ConsumerState<_EditSkuSheet> createState() => _EditSkuSheetState();
}

class _EditSkuSheetState extends ConsumerState<_EditSkuSheet> {
  late final TextEditingController _gstCtrl;
  late final TextEditingController _hsnCtrl;
  late final TextEditingController _rackCtrl;
  late final TextEditingController _reorderLevelCtrl;
  late final TextEditingController _reorderQtyCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    _gstCtrl = TextEditingController(
        text: p == null ? '' : (p.gstRateBp / 100).toStringAsFixed(p.gstRateBp % 100 == 0 ? 0 : 2));
    _hsnCtrl = TextEditingController();
    _rackCtrl = TextEditingController(text: p?.rackLocation ?? '');
    _reorderLevelCtrl = TextEditingController();
    _reorderQtyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _gstCtrl.dispose();
    _hsnCtrl.dispose();
    _rackCtrl.dispose();
    _reorderLevelCtrl.dispose();
    _reorderQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = <String, dynamic>{};
    final gstText = _gstCtrl.text.trim();
    if (gstText.isNotEmpty) {
      final gst = double.tryParse(gstText.replaceAll('%', ''));
      if (gst == null || gst < 0 || gst > 100) {
        setState(() => _error = 'GST must be a percentage between 0 and 100.');
        return;
      }
      body['gstRateBp'] = (gst * 100).round();
    }
    if (_hsnCtrl.text.trim().isNotEmpty) body['hsnCode'] = _hsnCtrl.text.trim();
    if (_rackCtrl.text.trim().isNotEmpty) body['rackLocation'] = _rackCtrl.text.trim();
    if (int.tryParse(_reorderLevelCtrl.text.trim()) != null) {
      body['reorderLevel'] = int.parse(_reorderLevelCtrl.text.trim());
    }
    if (int.tryParse(_reorderQtyCtrl.text.trim()) != null) {
      body['reorderQty'] = int.parse(_reorderQtyCtrl.text.trim());
    }
    if (body.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final auth = ref.read(authProvider);
    setState(() { _saving = true; _error = null; });
    try {
      final updated = await ref.read(repositoryProvider)
          .updateSku(auth.tenantPublicId!, auth.token!, widget.skuPublicId, body);
      if (!mounted) return;
      widget.onSaved?.call(updated);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.brandName} updated.'), backgroundColor: SevaCareColors.success));
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Edit ${widget.brandName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Only what you fill in changes — blank fields keep their current value.',
              style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: AppFormField(
                label: 'GST rate (%)', controller: _gstCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                placeholder: 'e.g. 12',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppFormField(label: 'HSN code', controller: _hsnCtrl, placeholder: 'e.g. 3004'),
            ),
          ]),
          const SizedBox(height: 8),
          AppFormField(label: 'Rack / shelf', controller: _rackCtrl, placeholder: 'e.g. A-3'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: AppFormField(
                label: 'Reorder level', controller: _reorderLevelCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                placeholder: 'alert below this',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppFormField(
                label: 'Reorder qty', controller: _reorderQtyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                placeholder: 'usual refill size',
              ),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: SevaCareColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          GradientButton(label: 'Save Changes', icon: Icons.check, fullWidth: true,
              isLoading: _saving, onPressed: _saving ? null : _save),
        ]),
      ),
    );
  }
}

/// One draft line of a delivery being entered — kept client-side until the
/// whole invoice posts as a single GRN document.
class _DraftGrnLine {
  final PharmacySku sku;
  final String batchNo;
  final String? expiryDate;
  final int qty;
  final int freeQty;
  final int mrpPaise;
  final int? purchasePricePaise;

  const _DraftGrnLine({
    required this.sku,
    required this.batchNo,
    this.expiryDate,
    required this.qty,
    required this.freeQty,
    required this.mrpPaise,
    this.purchasePricePaise,
  });

  Map<String, dynamic> toJson() => {
        'skuPublicId': sku.skuPublicId,
        'batchNo': batchNo,
        if (expiryDate != null) 'expiryDate': expiryDate,
        'qtyBaseUnits': qty,
        'freeQtyBaseUnits': freeQty,
        'mrpPaise': mrpPaise,
        if (purchasePricePaise != null) 'purchasePricePaise': purchasePricePaise,
      };
}

/// Receive a delivery as one GRN document: pick the supplier (or add one while
/// the truck waits), enter the invoice's lines — billed qty, free scheme qty,
/// MRP, purchase price — and post them together. The free "10+1" quantity is
/// what makes the owner's margin true, so it is a first-class field, not a note.
class _ReceiveStockSheet extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _ReceiveStockSheet({required this.onDone});
  @override
  ConsumerState<_ReceiveStockSheet> createState() => _ReceiveStockSheetState();
}

class _ReceiveStockSheetState extends ConsumerState<_ReceiveStockSheet> {
  final _searchCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController(); // yyyy-MM-dd
  final _mrpCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  final _freeQtyCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();
  // New-product fields
  final _newBrandCtrl = TextEditingController();
  final _newGstCtrl = TextEditingController(text: '12');
  String _newType = 'Tablet';
  // New-supplier field
  final _newSupplierCtrl = TextEditingController();

  /// Product type → (base unit, dosage form). The base unit is what the ledger
  /// counts, so a syrup is ML and a tablet is TABLET — which also drives the
  /// colour the item shows at the counter.
  static const Map<String, (String, String)> _typeMap = {
    'Tablet': ('TABLET', 'Tablet'),
    'Capsule': ('CAPSULE', 'Capsule'),
    'Syrup': ('ML', 'Syrup'),
    'Injection': ('ML', 'Injection'),
    'Drops': ('ML', 'Drops'),
    'Cream/Ointment': ('GM', 'Cream'),
    'Other': ('UNIT', 'Other'),
  };

  List<PharmacySku> _results = [];
  PharmacySku? _selected;
  bool _addingNew = false;
  bool _saving = false;

  List<Supplier> _suppliers = [];
  String? _supplierId;
  bool _addingSupplier = false;

  final List<_DraftGrnLine> _lines = [];

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    for (final c in [_searchCtrl, _batchCtrl, _expiryCtrl, _mrpCtrl, _qtyCtrl, _freeQtyCtrl,
        _costCtrl, _invoiceCtrl, _newBrandCtrl, _newGstCtrl, _newSupplierCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    final auth = ref.read(authProvider);
    try {
      final s = await ref.read(repositoryProvider).listSuppliers(auth.tenantPublicId!, auth.token!);
      if (mounted) setState(() => _suppliers = s);
    } catch (_) {/* dropdown just stays empty */}
  }

  Future<void> _addSupplier() async {
    final name = _newSupplierCtrl.text.trim();
    if (name.isEmpty) return;
    final auth = ref.read(authProvider);
    try {
      final s = await ref.read(repositoryProvider)
          .createSupplier(auth.tenantPublicId!, auth.token!, {'supplierName': name});
      if (mounted) {
        setState(() {
          if (!_suppliers.any((x) => x.supplierPublicId == s.supplierPublicId)) _suppliers.add(s);
          _supplierId = s.supplierPublicId;
          _addingSupplier = false;
          _newSupplierCtrl.clear();
        });
      }
    } catch (e) {
      _toast(_friendly(e));
    }
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) { setState(() => _results = []); return; }
    final auth = ref.read(authProvider);
    try {
      final r = await ref.read(repositoryProvider).searchCatalog(auth.tenantPublicId!, auth.token!, q.trim());
      if (mounted) setState(() => _results = r);
    } catch (_) {/* ignore */}
  }

  /// Validates the line fields, resolving (or creating) the product first.
  Future<_DraftGrnLine?> _buildLine() async {
    final auth = ref.read(authProvider);
    var sku = _selected;
    if (_addingNew) {
      final brand = _newBrandCtrl.text.trim();
      if (brand.isEmpty) { _toast('Enter the new product\'s name.'); return null; }
      final gst = int.tryParse(_newGstCtrl.text.trim()) ?? 12;
      final type = _typeMap[_newType] ?? ('UNIT', 'Other');
      sku = await ref.read(repositoryProvider).createSku(auth.tenantPublicId!, auth.token!, {
        'brandName': brand,
        'baseUnit': type.$1,
        'dosageForm': type.$2,
        'gstRateBp': gst * 100,
      });
    }
    if (sku == null) {
      // The common trap: a name was typed into search but no suggestion tapped.
      _toast(_searchCtrl.text.trim().isNotEmpty
          ? 'Tap the medicine in the list to pick it, or use “Add a new product”.'
          : 'Pick a product or add a new one.');
      return null;
    }
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (_batchCtrl.text.trim().isEmpty || qty <= 0) {
      _toast('Enter a batch number and a quantity.');
      return null;
    }
    final mrpRupees = double.tryParse(_mrpCtrl.text.trim()) ?? 0;
    final costRupees = double.tryParse(_costCtrl.text.trim());
    return _DraftGrnLine(
      sku: sku,
      batchNo: _batchCtrl.text.trim(),
      expiryDate: _expiryCtrl.text.trim().isEmpty ? null : _expiryCtrl.text.trim(),
      qty: qty,
      freeQty: int.tryParse(_freeQtyCtrl.text.trim()) ?? 0,
      mrpPaise: (mrpRupees * 100).round(),
      purchasePricePaise: costRupees == null ? null : (costRupees * 100).round(),
    );
  }

  void _clearLineFields() {
    for (final c in [_searchCtrl, _batchCtrl, _expiryCtrl, _mrpCtrl, _qtyCtrl, _freeQtyCtrl, _costCtrl,
        _newBrandCtrl]) {
      c.clear();
    }
    setState(() { _selected = null; _addingNew = false; _results = []; });
  }

  Future<void> _addLine() async {
    // Guard the whole build — creating a new product can fail on the network, and
    // an uncaught error there is exactly what made this button look dead before.
    setState(() => _saving = true);
    try {
      final line = await _buildLine();
      if (line == null) return;
      setState(() => _lines.add(line));
      _clearLineFields();
    } catch (e) {
      _toast(_friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _lineFieldsInUse =>
      _selected != null || _addingNew || _batchCtrl.text.trim().isNotEmpty || _qtyCtrl.text.trim().isNotEmpty;

  Future<void> _post() async {
    final auth = ref.read(authProvider);
    setState(() => _saving = true);
    try {
      // Whatever is still typed into the line fields rides along — the last
      // line of an invoice should not need an extra "Add line" tap.
      final pending = List<_DraftGrnLine>.from(_lines);
      if (_lineFieldsInUse) {
        final line = await _buildLine();
        if (line == null) return;
        pending.add(line);
      }
      if (pending.isEmpty) {
        _toast('Add at least one item from the delivery.');
        return;
      }
      final posted = await ref.read(repositoryProvider).postGrn(auth.tenantPublicId!, auth.token!, {
        if (_supplierId != null) 'supplierPublicId': _supplierId,
        if (_invoiceCtrl.text.trim().isNotEmpty) 'supplierInvoiceNo': _invoiceCtrl.text.trim(),
        'lines': pending.map((l) => l.toJson()).toList(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Delivery ${posted.grnPublicId} posted — ${posted.totalQtyBase} units in.'),
        backgroundColor: SevaCareColors.success,
      ));
    } catch (e) {
      _toast(_friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String s) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s), backgroundColor: SevaCareColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          const Text('Receive Delivery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('One delivery, any number of items — they post together as one receipt.',
              style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 16),

          // ── Supplier & invoice ────────────────────────────────────────────
          if (!_addingSupplier) Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _supplierId,
                decoration: const InputDecoration(labelText: 'Supplier (optional)', isDense: true),
                items: [
                  const DropdownMenuItem(value: null, child: Text('No supplier')),
                  for (final s in _suppliers)
                    DropdownMenuItem(value: s.supplierPublicId, child: Text(s.supplierName, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _supplierId = v),
              ),
            ),
            TextButton(onPressed: () => setState(() => _addingSupplier = true), child: const Text('New')),
          ]) else Row(children: [
            Expanded(child: AppFormField(label: 'New supplier name', controller: _newSupplierCtrl, placeholder: 'e.g. Sri Balaji Agencies')),
            const SizedBox(width: 8),
            TextButton(onPressed: _addSupplier, child: const Text('Add')),
            TextButton(onPressed: () => setState(() => _addingSupplier = false), child: const Text('Cancel')),
          ]),
          const SizedBox(height: 10),
          AppFormField(label: 'Supplier invoice no. (optional)', controller: _invoiceCtrl, placeholder: 'As printed on the invoice'),

          // ── Already-added lines ───────────────────────────────────────────
          if (_lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('On this delivery (${_lines.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            for (var i = 0; i < _lines.length; i++)
              GlassCard(
                borderWidth: 0.8,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_lines[i].sku.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        'Batch ${_lines[i].batchNo} · ${_lines[i].qty}${_lines[i].freeQty > 0 ? '+${_lines[i].freeQty} free' : ''} units',
                        style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted),
                      ),
                    ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: SevaCareColors.textMuted),
                    onPressed: () => setState(() => _lines.removeAt(i)),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 14),

          // ── Product for the next line ─────────────────────────────────────
          if (!_addingNew) ...[
            if (_selected == null) ...[
              AppFormField(
                label: 'Item on the invoice',
                controller: _searchCtrl,
                placeholder: 'Search the catalog…',
                onChanged: _search,
                suffixIcon: const Icon(Icons.search),
              ),
              for (final s in _results.take(6))
                ListTile(
                  dense: true,
                  title: Text(s.brandName),
                  onTap: () => setState(() { _selected = s; _results = []; }),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add a new product'),
                onPressed: () => setState(() => _addingNew = true),
              ),
            ] else
              GlassCard(
                borderWidth: 0.8,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(_selected!.brandName, style: const TextStyle(fontWeight: FontWeight.w600))),
                  TextButton(onPressed: () => setState(() => _selected = null), child: const Text('Change')),
                ]),
              ),
          ] else ...[
            AppFormField(label: 'New product name', controller: _newBrandCtrl, required: true, placeholder: 'e.g. Dolo 650'),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _newType,
                  decoration: const InputDecoration(labelText: 'Type', isDense: true),
                  items: [for (final t in _typeMap.keys) DropdownMenuItem(value: t, child: Text(t))],
                  onChanged: (v) => setState(() => _newType = v ?? 'Tablet'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppFormField(label: 'GST %', controller: _newGstCtrl, keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              ),
            ]),
            TextButton(onPressed: () => setState(() => _addingNew = false), child: const Text('Pick an existing product instead')),
          ],
          const SizedBox(height: 12),
          AppFormField(label: 'Batch number', controller: _batchCtrl, required: true, placeholder: 'As printed on the pack'),
          const SizedBox(height: 10),
          AppFormField(label: 'Expiry (YYYY-MM-DD)', controller: _expiryCtrl, placeholder: '2027-06-30',
              keyboardType: TextInputType.datetime),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: AppFormField(label: 'Billed qty (units)', controller: _qtyCtrl, required: true, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
            const SizedBox(width: 12),
            Expanded(child: AppFormField(label: 'Free qty (10+1)', controller: _freeQtyCtrl, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: AppFormField(label: 'MRP (₹ per unit)', controller: _mrpCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
            const SizedBox(width: 12),
            Expanded(child: AppFormField(label: 'Purchase ₹ per unit', controller: _costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Add line & next item'),
            onPressed: _saving ? null : _addLine,
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: _lines.isEmpty ? 'Post Delivery' : 'Post Delivery (${_lines.length}${_lineFieldsInUse ? '+1' : ''} lines)',
            icon: Icons.check,
            fullWidth: true,
            isLoading: _saving,
            onPressed: _saving ? null : _post,
          ),
        ]),
      ),
    );
  }
}

// ── Today ───────────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab();
  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

enum _Period { day, week, month, custom }

class _TodayTabState extends ConsumerState<_TodayTab> {
  static const _periods = [(_Period.day, 'Day'), (_Period.week, 'Week'), (_Period.month, 'Month'), (_Period.custom, 'Custom')];

  _Period _period = _Period.day;
  DateTimeRange _customRange = DateTimeRange(start: DateTime.now(), end: DateTime.now());

  MoneyView? _money; // Day only — drawer count and true margin are single-day concepts.
  DaySummary? _summary;
  List<DailyTotal> _trend = [];
  List<RecentReturn> _refunds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  (DateTime, DateTime) _range() {
    final today = DateTime.now();
    return switch (_period) {
      _Period.day => (today, today),
      _Period.week => (today.subtract(const Duration(days: 6)), today),
      _Period.month => (today.subtract(const Duration(days: 29)), today),
      _Period.custom => (_customRange.start, _customRange.end),
    };
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _customRange,
    );
    if (picked != null) {
      setState(() { _customRange = picked; _period = _Period.custom; });
      _load();
    }
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    final repo = ref.read(repositoryProvider);
    final (from, to) = _range();
    final fromIso = _iso(from), toIso = _iso(to);
    setState(() => _loading = true);
    try {
      final summary = await repo.rangeSummary(auth.tenantPublicId!, auth.token!, fromIso, toIso);
      final trend = await repo.dailyTotals(auth.tenantPublicId!, auth.token!, fromIso, toIso);
      final refunds = await repo.recentReturns(auth.tenantPublicId!, auth.token!);
      MoneyView? money;
      if (_period == _Period.day) {
        try { money = await repo.moneyView(auth.tenantPublicId!, auth.token!); } catch (_) {/* card just hides */}
      }
      if (mounted) setState(() { _summary = summary; _trend = trend; _refunds = refunds; _money = money; });
    } catch (_) {/* empty */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final m = _money;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _periodSelector(),
          const SizedBox(height: 12),
          if (_loading) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (s != null) ...[
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_period == _Period.day ? "Today's takings" : 'Takings this period',
                    style: const TextStyle(color: SevaCareColors.textMuted)),
                const SizedBox(height: 4),
                Text(_rupees(s.totalPaise), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: SevaCareColors.primary)),
                Text('${s.saleCount} bill${s.saleCount == 1 ? '' : 's'} · GST ${_rupees(s.gstPaise)}'
                    '${m != null && m.refundsPaise > 0 ? ' · refunds ${_rupees(m.refundsPaise)}' : ''}',
                    style: const TextStyle(color: SevaCareColors.textMuted)),
                if (m != null) ...[
                  const Divider(height: 20),
                  // True margin: takings − refunds − what those units cost at GRN.
                  // A day-close/drawer concept, so only shown for the Day filter.
                  Row(children: [
                    Expanded(child: _stat('Margin', _rupees(m.marginPaise),
                        m.marginPaise >= 0 ? SevaCareColors.success : SevaCareColors.error)),
                    Expanded(child: _stat('Cost of goods', _rupees(m.costPaise), SevaCareColors.textMuted)),
                  ]),
                  if (m.unknownCostLines > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${m.unknownCostLines} line${m.unknownCostLines == 1 ? '' : 's'} sold from batches with no purchase price — margin excludes them.',
                        style: const TextStyle(fontSize: 11, color: SevaCareColors.warning),
                      ),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            if (s.byPaymentMode.isNotEmpty) ...[
              _paymentPieCard(s),
              const SizedBox(height: 12),
            ],
            if (_trend.length > 1) ...[
              _trendLineCard(),
              const SizedBox(height: 12),
            ],
            if (m != null) ...[
              _dayCloseCard(m),
              const SizedBox(height: 20),
            ],
            const _TrendsCard(),
            const SizedBox(height: 20),
            const _KhataCard(),
            const SizedBox(height: 20),
            const _ReportsCard(),
            const SizedBox(height: 20),
            _refundsSection(),
          ],
        ],
      ),
        ),
      ),
    );
  }

  Widget _periodSelector() => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final p in _periods)
          ChoiceChip(
            label: Text(p.$2),
            selected: _period == p.$1,
            onSelected: (_) {
              if (p.$1 == _Period.custom) {
                _pickCustomRange();
              } else if (_period != p.$1) {
                setState(() => _period = p.$1);
                _load();
              }
            },
            selectedColor: SevaCareColors.primarySoft,
          ),
      ]);

  Widget _paymentPieCard(DaySummary s) {
    final total = s.byPaymentMode.fold<int>(0, (sum, p) => sum + p.totalPaise);
    return GlassCard(
      child: Row(children: [
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 30,
            sections: [
              for (final p in s.byPaymentMode)
                PieChartSectionData(
                  value: p.totalPaise.toDouble(),
                  color: _paymentColor(p.paymentMode),
                  title: '',
                  radius: 22,
                ),
            ],
          )),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Payment mix', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            for (final p in s.byPaymentMode)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                      color: _paymentColor(p.paymentMode), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p.paymentMode, style: const TextStyle(fontSize: 12))),
                  Text(total == 0 ? '0%' : '${(p.totalPaise * 100 / total).round()}%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }

  Color _paymentColor(String mode) {
    for (final m in _paymentModes) {
      if (m.$1 == mode) return m.$4;
    }
    return SevaCareColors.textMuted;
  }

  Widget _trendLineCard() {
    final maxY = _trend.fold<int>(0, (mx, t) => t.totalPaise > mx ? t.totalPaise : mx);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sales trend', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 4),
        const Text('The shape of the business over this period, not just one number.',
            style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: LineChart(LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            minY: 0,
            maxY: maxY == 0 ? 1 : maxY * 1.2,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots.map((s) {
                  final t = _trend[s.x.toInt()];
                  return LineTooltipItem('${t.saleDate}\n${_rupees(t.totalPaise)}',
                      const TextStyle(color: Colors.white, fontSize: 11));
                }).toList(),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (int i = 0; i < _trend.length; i++) FlSpot(i.toDouble(), _trend[i].totalPaise.toDouble())],
                isCurved: true,
                color: SevaCareColors.primary,
                barWidth: 3,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: SevaCareColors.primarySoft),
              ),
            ],
          )),
        ),
      ]),
    );
  }

  Widget _refundsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.keyboard_return, size: 18, color: SevaCareColors.warning),
        const SizedBox(width: 8),
        const Text('Refunds', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      ]),
      const SizedBox(height: 4),
      const Text('Where refunded money went — most recent first.',
          style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
      const SizedBox(height: 8),
      if (_refunds.isEmpty)
        const Padding(padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No refunds yet.', style: TextStyle(color: SevaCareColors.textMuted)))
      else
        for (final r in _refunds) _refundTile(r),
    ]);
  }

  Widget _refundTile(RecentReturn r) => GlassCard(
        borderWidth: 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Invoice ${r.invoiceNo}', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${r.lineCount} item${r.lineCount == 1 ? '' : 's'} · via ${r.refundMode}'
                  '${r.reason != null && r.reason!.isNotEmpty ? ' · ${r.reason}' : ''}',
                  style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted)),
            ]),
          ),
          Text('- ${_rupees(r.refundPaise)}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: SevaCareColors.error)),
        ]),
      );

  /// The drawer count. Open: expected cash + a counted field + Close Day.
  /// Closed: the record — counted vs expected, variance, who counted.
  Widget _dayCloseCard(MoneyView m) {
    final close = m.dayClose;
    if (close != null) {
      final varianceColor = close.variancePaise == 0
          ? SevaCareColors.success
          : (close.variancePaise > 0 ? SevaCareColors.warning : SevaCareColors.error);
      return GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.lock_outline, size: 18, color: SevaCareColors.success),
            const SizedBox(width: 8),
            const Text('Day closed', style: TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            if (close.closedBy != null)
              Text('by ${close.closedBy}', style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _stat('Expected cash', _rupees(close.expectedCashPaise), SevaCareColors.textMuted)),
            Expanded(child: _stat('Counted', _rupees(close.countedCashPaise), SevaCareColors.text)),
            Expanded(child: _stat('Variance',
                '${close.variancePaise > 0 ? '+' : ''}${_rupees(close.variancePaise)}', varianceColor)),
          ]),
          if (close.note != null && close.note!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(close.note!, style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            ),
        ]),
      );
    }
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.point_of_sale_outlined, size: 18, color: SevaCareColors.primary),
          const SizedBox(width: 8),
          const Text('Close the day', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Text('The drawer should hold ${_rupees(m.expectedCashPaise)} in cash '
            '(cash sales minus cash refunds). Count it and close.',
            style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.calculate_outlined, size: 18),
          label: const Text('Count drawer & close day'),
          onPressed: () => _openDayCloseSheet(m),
        ),
      ]),
    );
  }

  void _openDayCloseSheet(MoneyView m) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SevaCareColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _DayCloseSheet(expectedCashPaise: m.expectedCashPaise, onDone: _load),
    );
  }

  Widget _stat(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted)),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      );

}

/// The khata — who owes the store money. Every CREDIT sale with a mobile is a
/// debt on record; this card lists the balances and takes repayments, so
/// "put it on my account" stops living in the owner's memory.
class _KhataCard extends ConsumerStatefulWidget {
  const _KhataCard();
  @override
  ConsumerState<_KhataCard> createState() => _KhataCardState();
}

class _KhataCardState extends ConsumerState<_KhataCard> {
  List<CreditOutstanding> _dues = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    try {
      final list = await ref.read(repositoryProvider)
          .creditOutstanding(auth.tenantPublicId!, auth.token!);
      if (mounted) setState(() => _dues = list);
    } catch (_) {/* card just shows empty */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _receivePayment(CreditOutstanding c) async {
    final amountCtrl = TextEditingController(
        text: (c.outstandingPaise / 100).toStringAsFixed(2));
    String via = 'CASH';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        return AlertDialog(
          backgroundColor: SevaCareColors.surface,
          title: Text('Receive from ${c.customerName ?? c.customerMobile}'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Outstanding: ${_rupees(c.outstandingPaise)}',
                style: const TextStyle(color: SevaCareColors.textMuted, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final m in const ['CASH', 'UPI', 'CARD'])
                ChoiceChip(
                  label: Text(m),
                  selected: via == m,
                  onSelected: (_) => setDialogState(() => via = m),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record Payment')),
          ],
        );
      }),
    );
    if (ok != true || !mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    final auth = ref.read(authProvider);
    try {
      await ref.read(repositoryProvider).recordCreditPayment(
          auth.tenantPublicId!, auth.token!, {
        'customerMobile': c.customerMobile,
        'amountPaise': (amount * 100).round(),
        'paidVia': via,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _dues.fold<int>(0, (s, c) => s + c.outstandingPaise);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.menu_book_outlined, size: 18, color: SevaCareColors.warning),
          const SizedBox(width: 8),
          const Text('Credit ledger (Khata)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          if (total > 0)
            Text(_rupees(total), style: const TextStyle(fontWeight: FontWeight.w800, color: SevaCareColors.warning)),
        ]),
        const SizedBox(height: 4),
        const Text('Customers who bought on credit and what they still owe.',
            style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
        else if (_dues.isEmpty)
          const Text('No credit outstanding — everyone has settled up.',
              style: TextStyle(color: SevaCareColors.textMuted))
        else
          for (final c in _dues)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (c.customerName != null)
                      Text(c.customerName!,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5))
                    else
                      MaskedText(c.customerMobile,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    if (c.customerName != null)
                      MaskedText(c.customerMobile,
                          style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted))
                    else
                      const Text('no name on record',
                          style: TextStyle(fontSize: 11, color: SevaCareColors.textMuted)),
                  ]),
                ),
                Text(_rupees(c.outstandingPaise),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: SevaCareColors.warning)),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => _receivePayment(c),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact),
                  child: const Text('Receive', style: TextStyle(fontSize: 12.5)),
                ),
              ]),
            ),
      ]),
    );
  }
}

/// What is selling — the reorder-planning view. A period toggle (Today, Week,
/// Month, Year) reloads the ranked top-sellers, each with a bar of its share so
/// the fast movers are obvious at a glance. Owns its own fetch so switching the
/// window never reloads the whole Today tab.
class _TrendsCard extends ConsumerStatefulWidget {
  const _TrendsCard();
  @override
  ConsumerState<_TrendsCard> createState() => _TrendsCardState();
}

class _TrendsCardState extends ConsumerState<_TrendsCard> {
  static const _periods = [('DAY', 'Today'), ('WEEK', 'Week'), ('MONTH', 'Month'), ('YEAR', 'Year')];
  String _period = 'WEEK';
  List<TopMedicine> _top = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    setState(() => _loading = true);
    try {
      final t = await ref.read(repositoryProvider)
          .topMedicines(auth.tenantPublicId!, auth.token!, period: _period, limit: 8);
      if (mounted) setState(() => _top = t);
    } catch (_) {
      if (mounted) setState(() => _top = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxQty = _top.isEmpty ? 1 : _top.map((t) => t.qtySold).reduce((a, b) => a > b ? a : b);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.trending_up, size: 18, color: SevaCareColors.primary),
          SizedBox(width: 8),
          Text('Top sellers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 4),
        const Text('Plan your next order — what is moving over the window.',
            style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final p in _periods)
            ChoiceChip(
              label: Text(p.$2),
              selected: _period == p.$1,
              onSelected: (_) {
                if (_period != p.$1) {
                  setState(() => _period = p.$1);
                  _load();
                }
              },
              selectedColor: SevaCareColors.primarySoft,
            ),
        ]),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (_top.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No sales in this period yet.', style: TextStyle(color: SevaCareColors.textMuted)),
          )
        else
          for (final t in _top) _trendRow(t, maxQty),
      ]),
    );
  }

  Widget _trendRow(TopMedicine t, int maxQty) {
    final style = _medStyleOf(t.dosageForm, null);
    final frac = maxQty == 0 ? 0.0 : (t.qtySold / maxQty).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(style.icon, size: 15, color: style.color),
          const SizedBox(width: 6),
          Expanded(child: Text(t.brandName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis)),
          Text('${t.qtySold} sold', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text(_rupees(t.revenuePaise), style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: frac.toDouble(),
            minHeight: 6,
            backgroundColor: SevaCareColors.surfaceMuted,
            valueColor: AlwaysStoppedAnimation(style.color),
          ),
        ),
      ]),
    );
  }
}

/// A downloadable, date-ranged sales/audit register — the line-level record an
/// accountant or a drug inspector asks for ("what all medicines were sold").
class _ReportsCard extends ConsumerStatefulWidget {
  const _ReportsCard();
  @override
  ConsumerState<_ReportsCard> createState() => _ReportsCardState();
}

class _ReportsCardState extends ConsumerState<_ReportsCard> {
  DateTimeRange _range = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 6)), end: DateTime.now());
  bool _busy = false;

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _export({required bool print}) async {
    final auth = ref.read(authProvider);
    setState(() => _busy = true);
    try {
      final lines = await ref.read(repositoryProvider).salesRegister(
          auth.tenantPublicId!, auth.token!, _iso(_range.start), _iso(_range.end));
      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No sales in this date range.')));
        }
        return;
      }
      final shop = auth.capabilities?.tenantName ?? 'Pharmacy';
      if (print) {
        await PharmacySalesRegisterPdf.print(
            shopName: shop, fromLabel: _iso(_range.start), toLabel: _iso(_range.end), lines: lines);
      } else {
        await PharmacySalesRegisterPdf.download(
            shopName: shop, fromLabel: _iso(_range.start), toLabel: _iso(_range.end), lines: lines);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportGst() async {
    final auth = ref.read(authProvider);
    setState(() => _busy = true);
    try {
      final slabs = await ref.read(repositoryProvider).gstSummary(
          auth.tenantPublicId!, auth.token!, _iso(_range.start), _iso(_range.end));
      if (slabs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No sales in this date range.')));
        }
        return;
      }
      final shop = ref.read(authProvider).capabilities?.tenantName ?? 'Pharmacy';
      await PharmacyGstSummaryPdf.download(
          shopName: shop, fromLabel: _iso(_range.start), toLabel: _iso(_range.end), slabs: slabs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.summarize_outlined, size: 18, color: SevaCareColors.primary),
          SizedBox(width: 8),
          Text('Reports', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
        const SizedBox(height: 4),
        const Text('The sales register and GST slab summary for a date range — for your accountant or a drug inspector.',
            style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickRange,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: SevaCareColors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SevaCareColors.border),
            ),
            child: Row(children: [
              const Icon(Icons.date_range, size: 16, color: SevaCareColors.textMuted),
              const SizedBox(width: 8),
              Text('${_iso(_range.start)}  →  ${_iso(_range.end)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Print'),
              onPressed: _busy ? null : () => _export(print: true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GradientButton(
              label: 'Sales Register PDF',
              icon: Icons.download_outlined,
              isLoading: _busy,
              onPressed: _busy ? null : () => _export(print: false),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.percent, size: 18),
          label: const Text('GST Summary PDF'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(42)),
          onPressed: _busy ? null : _exportGst,
        ),
      ]),
    );
  }
}

/// Count the physical drawer and close the day. The variance is computed and
/// shown before confirming, so an honest short drawer is recorded, not hidden.
class _DayCloseSheet extends ConsumerStatefulWidget {
  final int expectedCashPaise;
  final VoidCallback onDone;
  const _DayCloseSheet({required this.expectedCashPaise, required this.onDone});
  @override
  ConsumerState<_DayCloseSheet> createState() => _DayCloseSheetState();
}

class _DayCloseSheetState extends ConsumerState<_DayCloseSheet> {
  final _countedCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _countedCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int? get _countedPaise {
    final v = double.tryParse(_countedCtrl.text.trim());
    return v == null ? null : (v * 100).round();
  }

  Future<void> _close() async {
    final counted = _countedPaise;
    if (counted == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the cash you counted.'), backgroundColor: SevaCareColors.error));
      return;
    }
    final auth = ref.read(authProvider);
    setState(() => _saving = true);
    try {
      await ref.read(repositoryProvider).closeDay(auth.tenantPublicId!, auth.token!, {
        'countedCashPaise': counted,
        if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Day closed.'), backgroundColor: SevaCareColors.success));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final counted = _countedPaise;
    final variance = counted == null ? null : counted - widget.expectedCashPaise;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        const Text('Close the day', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Expected in drawer: ${_rupees(widget.expectedCashPaise)}',
            style: const TextStyle(color: SevaCareColors.textMuted)),
        const SizedBox(height: 16),
        AppFormField(
          label: 'Cash counted (₹)',
          controller: _countedCtrl,
          required: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        if (variance != null) ...[
          const SizedBox(height: 6),
          Text(
            variance == 0
                ? 'Drawer matches exactly.'
                : '${variance > 0 ? 'Over' : 'Short'} by ${_rupees(variance.abs())}.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: variance == 0
                  ? SevaCareColors.success
                  : (variance > 0 ? SevaCareColors.warning : SevaCareColors.error),
            ),
          ),
        ],
        const SizedBox(height: 10),
        AppFormField(label: 'Note (optional)', controller: _noteCtrl, placeholder: 'e.g. ₹10 coin jar'),
        const SizedBox(height: 16),
        GradientButton(label: 'Close Day', icon: Icons.lock_outline, fullWidth: true,
            isLoading: _saving, onPressed: _saving ? null : _close),
      ]),
    );
  }
}

/// Return items against a bill. The server says what is still returnable and
/// prices the refund; this sheet only chooses quantities and dispositions.
class _ReturnSheet extends ConsumerStatefulWidget {
  final SaleSummary sale;
  final VoidCallback onDone;
  const _ReturnSheet({required this.sale, required this.onDone});
  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  List<ReturnableLine> _lines = [];
  final Map<String, int> _qty = {};          // key: sku|batch
  final Map<String, bool> _quarantine = {};  // key: sku|batch
  String _refundMode = 'CASH';
  bool _loading = true;
  bool _saving = false;

  String _key(ReturnableLine l) => '${l.skuPublicId}|${l.batchPublicId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    try {
      final lines = await ref.read(repositoryProvider)
          .returnableLines(auth.tenantPublicId!, auth.token!, widget.sale.salePublicId);
      if (mounted) setState(() => _lines = lines);
    } catch (_) {/* sheet shows empty */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _refundPaise {
    var total = 0;
    for (final l in _lines) {
      final q = _qty[_key(l)] ?? 0;
      if (q <= 0) continue;
      total += q == l.qtySold ? l.netPaise : l.perUnitPaise * q;
    }
    return total;
  }

  Future<void> _post() async {
    final picked = _lines.where((l) => (_qty[_key(l)] ?? 0) > 0).toList();
    if (picked.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Choose at least one item to return.'), backgroundColor: SevaCareColors.error));
      return;
    }
    final auth = ref.read(authProvider);
    setState(() => _saving = true);
    try {
      final posted = await ref.read(repositoryProvider).postReturn(auth.tenantPublicId!, auth.token!, {
        'salePublicId': widget.sale.salePublicId,
        'refundMode': _refundMode,
        'lines': [
          for (final l in picked)
            {
              'skuPublicId': l.skuPublicId,
              'batchPublicId': l.batchPublicId,
              'qtyBaseUnits': _qty[_key(l)],
              'disposition': (_quarantine[_key(l)] ?? false) ? 'QUARANTINE' : 'RESTOCK',
            },
        ],
      });
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Refunded ${_rupees(posted.refundPaise)} against ${widget.sale.invoiceNo}.'),
        backgroundColor: SevaCareColors.success,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendly(e)), backgroundColor: SevaCareColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text('Return items — ${widget.sale.invoiceNo}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Restock what can be resold; quarantine anything opened or doubtful.',
              style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 14),
          if (_loading)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_lines.every((l) => l.qtyReturnable == 0))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Everything on this bill has already been returned.',
                  style: TextStyle(color: SevaCareColors.textMuted)),
            )
          else
            for (final l in _lines.where((l) => l.qtyReturnable > 0)) _lineTile(l),
          const SizedBox(height: 8),
          const Text('Refund by', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          _PaymentModeChips(
            codes: const ['CASH', 'UPI', 'CARD'],
            selected: _refundMode,
            onChanged: (v) => setState(() => _refundMode = v),
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: _refundPaise > 0 ? 'Refund ${_rupees(_refundPaise)}' : 'Refund',
            icon: Icons.keyboard_return,
            fullWidth: true,
            isLoading: _saving,
            onPressed: _saving ? null : _post,
          ),
        ]),
      ),
    );
  }

  Widget _lineTile(ReturnableLine l) {
    final key = _key(l);
    final qty = _qty[key] ?? 0;
    final quarantined = _quarantine[key] ?? false;
    return GlassCard(
      borderWidth: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.brandName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('bought ${l.qtySold}${l.qtyAlreadyReturned > 0 ? ' · returned ${l.qtyAlreadyReturned}' : ''} · ${_rupees(l.perUnitPaise)}/unit',
                  style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: qty > 0 ? () => setState(() => _qty[key] = qty - 1) : null,
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: qty < l.qtyReturnable ? () => setState(() => _qty[key] = qty + 1) : null,
          ),
        ]),
        if (qty > 0)
          Row(children: [
            const Text('Quarantine (not resellable)', style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            const Spacer(),
            Switch(
              value: quarantined,
              onChanged: (v) => setState(() => _quarantine[key] = v),
            ),
          ]),
      ]),
    );
  }
}

String _friendly(Object e) {
  final s = e.toString();
  final idx = s.indexOf('message');
  if (idx >= 0 && s.length < 400) return s.replaceAll('Exception:', '').trim();
  return 'Something went wrong. Please try again.';
}

// ── Staff manager ─────────────────────────────────────────────────────────────

/// The owner adds and removes counter staff here. A staff member is just another
/// login for this store (a STAFF admin_user) — they sign in through the same
/// pharmacy login with their own mobile and the default OTP. Owner-only.
/// The Team tab — the store's people, managed the same way a hospital manages
/// its staff, but in the store's own space. The owner adds counter staff (each
/// signs in with their own mobile + OTP); counter staff see the team list.
class _TeamTab extends ConsumerStatefulWidget {
  const _TeamTab();
  @override
  ConsumerState<_TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends ConsumerState<_TeamTab> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  List<AdminUserRecord> _staff = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    setState(() => _loading = true);
    try {
      final s = await ref.read(repositoryProvider).listStaff(auth.tenantPublicId!, auth.token!, activeOnly: false);
      if (mounted) setState(() => _staff = s);
    } catch (_) {/* show empty */} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final name = _nameCtrl.text.trim();
    final mobile = _mobileCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Enter the staff member\'s name.'); return; }
    if (mobile.length != 10) { setState(() => _error = 'Enter a valid 10-digit mobile number.'); return; }
    final auth = ref.read(authProvider);
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(repositoryProvider).createStaff(
            auth.tenantPublicId!, auth.token!,
            AdminUserUpsertRequest(fullName: name, mobileNumber: mobile, userType: 'STAFF'),
          );
      _nameCtrl.clear();
      _mobileCtrl.clear();
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name can now sign in with OTP 0000'), backgroundColor: SevaCareColors.success),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deactivate(AdminUserRecord s) async {
    final auth = ref.read(authProvider);
    try {
      await ref.read(repositoryProvider).deactivateStaff(auth.tenantPublicId!, s.adminPublicId, auth.token!);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final active = _staff.where((s) => s.active).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          const Text('Counter Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Add the people who run your counter. Each signs in with their own mobile and OTP 0000.',
              style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
          const SizedBox(height: 16),
          AppFormField(label: 'Name', controller: _nameCtrl, required: true, placeholder: 'e.g. Suresh'),
          const SizedBox(height: 10),
          AppFormField(
            label: 'Mobile number',
            controller: _mobileCtrl,
            required: true,
            keyboardType: TextInputType.phone,
            placeholder: '10-digit mobile',
            inputFormatters: [MobileInputFormatter()],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: SevaCareColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 14),
          GradientButton(label: 'Add Staff', icon: Icons.person_add_alt, fullWidth: true, isLoading: _saving,
              onPressed: _saving ? null : _add),
          const SizedBox(height: 20),
          Text('Your team (${active.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (active.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No staff yet — you run the counter alone.', style: TextStyle(color: SevaCareColors.textMuted)))
          else for (final s in active) _staffTile(s),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _staffTile(AdminUserRecord s) => GlassCard(
        borderWidth: 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(children: [
          const CircleAvatar(radius: 16, backgroundColor: SevaCareColors.primarySoft,
              child: Icon(Icons.person_outline, size: 18, color: SevaCareColors.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (s.mobileNumber != null && s.mobileNumber!.isNotEmpty)
                MaskedText(s.mobileNumber!,
                    style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted))
              else
                const Text('—', style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            ]),
          ),
          TextButton(
            onPressed: () => _deactivate(s),
            style: TextButton.styleFrom(foregroundColor: SevaCareColors.error),
            child: const Text('Remove'),
          ),
        ]),
      );
}

// ── Catalog import ────────────────────────────────────────────────────────────

/// One field of the catalog, and the column headers a supplier's file is likely
/// to call it. Order matters: `cost` is tried before `mrp` because a "Purchase
/// Rate" column contains "rate" and must never be mistaken for the selling price.
class _ImportField {
  final String key;
  final String label;
  final List<String> aliases;
  const _ImportField(this.key, this.label, this.aliases);
}

const List<_ImportField> _importFields = [
  _ImportField('brandName', 'Medicine name', ['name', 'brand', 'product', 'medicine', 'item', 'description', 'particulars']),
  _ImportField('manufacturer', 'Manufacturer', ['manufacturer', 'mfr', 'company', 'maker', 'marketer']),
  _ImportField('type', 'Type / form', ['type', 'form', 'dosage']),
  _ImportField('strength', 'Strength', ['strength', 'power', 'dose']),
  _ImportField('scheduleClass', 'Schedule (H / H1 / X)', ['schedule', 'sch']),
  _ImportField('gst', 'GST %', ['gst', 'tax', 'igst', 'cgst']),
  _ImportField('hsnCode', 'HSN code', ['hsn']),
  _ImportField('rackLocation', 'Rack / shelf', ['rack', 'shelf', 'location']),
  _ImportField('reorderLevel', 'Reorder level', ['reorder', 'minqty', 'minimum']),
  _ImportField('batchNo', 'Batch number', ['batch']),
  _ImportField('expiry', 'Expiry', ['expiry', 'exp', 'validity']),
  _ImportField('cost', 'Purchase price', ['cost', 'purchase', 'ptr', 'prate']),
  _ImportField('mrp', 'MRP', ['mrp', 'price', 'rate']),
  _ImportField('qty', 'Opening quantity', ['qty', 'quantity', 'stock', 'opening', 'units', 'pcs', 'nos']),
];

/// Load a supplier's whole list at once instead of typing each item — from the
/// file itself (.csv, .tsv or .xlsx, picked off the phone, tablet or shop
/// laptop) or by pasting the rows in, whichever the store finds easier.
///
/// Nothing is sent until the pharmacist has seen, column by column, what this
/// screen believes each one *means*, and said so. These rows land in the
/// catalog and the stock ledger directly: a "Purchase Rate" read as an MRP
/// would silently reprice the shelf, and a misread quantity column would create
/// stock that does not exist. So the mapping is shown, every guess is
/// overridable, the first rows are rendered exactly as they will be stored, and
/// the Import button stays dead until the box is ticked.
class _ImportCatalogSheet extends ConsumerStatefulWidget {
  final VoidCallback onDone;
  const _ImportCatalogSheet({required this.onDone});
  @override
  ConsumerState<_ImportCatalogSheet> createState() => _ImportCatalogSheetState();
}

class _ImportCatalogSheetState extends ConsumerState<_ImportCatalogSheet> {
  final _csvCtrl = TextEditingController();

  /// The raw file, exactly as read: row 0 is the header.
  List<List<String>> _grid = [];
  String? _sourceName;

  /// One entry per column of [_grid] — the field it feeds, or null for "ignore".
  List<String?> _mapping = [];

  bool _confirmed = false;
  bool _showPaste = false;
  bool _saving = false;
  String? _error;

  static const Map<String, String> _typeToBaseUnit = {
    'tablet': 'TABLET', 'tab': 'TABLET', 'capsule': 'CAPSULE', 'cap': 'CAPSULE',
    'syrup': 'ML', 'liquid': 'ML', 'suspension': 'ML', 'injection': 'ML', 'drops': 'ML',
    'cream': 'GM', 'ointment': 'GM', 'gel': 'GM', 'powder': 'GM',
  };

  @override
  void dispose() {
    _csvCtrl.dispose();
    super.dispose();
  }

  bool get _hasFile => _grid.length >= 2;
  bool get _nameMapped => _mapping.contains('brandName');

  /// A field claimed by two columns is ambiguous — we would silently keep one.
  List<String> get _duplicateFields {
    final seen = <String, int>{};
    for (final m in _mapping) {
      if (m != null) seen[m] = (seen[m] ?? 0) + 1;
    }
    return seen.entries.where((e) => e.value > 1).map((e) => e.key).toList();
  }

  // ── Reading the source ────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    setState(() => _error = null);
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'tsv', 'txt', 'xlsx'],
        withData: true, // web has no path — bytes are the only portable source
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes;
      if (bytes == null) {
        setState(() => _error = 'Could not read that file. Try again, or paste the rows instead.');
        return;
      }
      final name = f.name;
      final grid = name.toLowerCase().endsWith('.xlsx')
          ? _gridFromXlsx(bytes)
          : _parseDelimited(_decodeText(bytes));
      if (grid.length < 2) {
        setState(() => _error = 'That file has no rows under its header.');
        return;
      }
      _acceptGrid(grid, name);
    } catch (e) {
      setState(() => _error = 'Could not read that file — ${_friendly(e)}');
    }
  }

  /// Supplier exports are rarely UTF-8; a stray ₹ or a Windows-1252 byte must
  /// not blow up the whole import, so fall back to a lenient decode.
  String _decodeText(Uint8List bytes) {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }

  List<List<String>> _gridFromXlsx(Uint8List bytes) {
    final book = Excel.decodeBytes(bytes);
    if (book.tables.isEmpty) return const [];
    final sheet = book.tables[book.tables.keys.first]!;
    final rows = <List<String>>[];
    for (final row in sheet.rows) {
      final cells = row.map((c) => c?.value?.toString().trim() ?? '').toList();
      if (cells.any((c) => c.isNotEmpty)) rows.add(cells);
    }
    return rows;
  }

  void _acceptGrid(List<List<String>> grid, String source) {
    // Every row is padded to the header's width so a short trailing row can't
    // shift a value into the wrong column.
    final width = grid.first.length;
    final padded = grid
        .map((r) => List<String>.generate(width, (i) => i < r.length ? r[i].trim() : ''))
        .toList();
    setState(() {
      _grid = padded;
      _sourceName = source;
      _mapping = padded.first.map(_matchColumn).toList();
      _confirmed = false;
      _error = null;
    });
  }

  void _parsePaste() {
    final grid = _parseDelimited(_csvCtrl.text.trim());
    if (grid.length < 2) {
      setState(() => _error = 'Paste at least a header row and one product row.');
      return;
    }
    _acceptGrid(grid, 'pasted rows');
  }

  /// Splits pasted or CSV text. Excel/Numbers copy as TAB-separated, exported
  /// CSVs use commas, some European exports use semicolons — detect which by
  /// what the first line actually contains, preferring tabs (a tab in the first
  /// line is almost certainly the delimiter; a comma might be part of a name).
  /// Quoted fields, escaped quotes and embedded newlines are handled.
  List<List<String>> _parseDelimited(String input) {
    final firstLine = input.split(RegExp(r'[\r\n]')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
    final String delim;
    if (firstLine.contains('\t')) {
      delim = '\t';
    } else if (!firstLine.contains(',') && firstLine.contains(';')) {
      delim = ';';
    } else {
      delim = ',';
    }

    final rows = <List<String>>[];
    var field = StringBuffer();
    var row = <String>[];
    var inQuotes = false;
    for (var i = 0; i < input.length; i++) {
      final ch = input[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') { field.write('"'); i++; }
          else { inQuotes = false; }
        } else {
          field.write(ch);
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
        } else if (ch == delim) {
          row.add(field.toString()); field = StringBuffer();
        } else if (ch == '\n' || ch == '\r') {
          if (ch == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
          row.add(field.toString()); field = StringBuffer();
          if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
          row = <String>[];
        } else {
          field.write(ch);
        }
      }
    }
    row.add(field.toString());
    if (row.any((c) => c.trim().isNotEmpty)) rows.add(row);
    return rows;
  }

  String? _matchColumn(String header) {
    final h = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (h.isEmpty) return null;
    for (final f in _importFields) {
      if (f.aliases.any((k) => h == k || h.contains(k))) return f.key;
    }
    return null;
  }

  // ── Turning the grid into the payload ─────────────────────────────────────

  /// Pulls the first number out of whatever a supplier's file put in the cell —
  /// "₹1,250.50", "GST@12", "12 %", "Rs 45" — instead of failing on decoration.
  double? _numFrom(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'-?\d[\d,]*\.?\d*').firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(0)!.replaceAll(',', ''));
  }

  String? _normalizeDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return t;
    final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})$').firstMatch(t);
    if (m != null) {
      var y = m.group(3)!;
      if (y.length == 2) y = '20$y';
      final mo = m.group(2)!.padLeft(2, '0');
      final d = m.group(1)!.padLeft(2, '0');
      return '$y-$mo-$d';
    }
    // "MM/YYYY" pack-style expiry → first of that month.
    final my = RegExp(r'^(\d{1,2})[/-](\d{4})$').firstMatch(t);
    if (my != null) return '${my.group(2)}-${my.group(1)!.padLeft(2, '0')}-01';
    // "YYYY-MM" — the same thing the other way round.
    final ym = RegExp(r'^(\d{4})[/-](\d{1,2})$').firstMatch(t);
    if (ym != null) return '${ym.group(1)}-${ym.group(2)!.padLeft(2, '0')}-01';
    return null;
  }

  Map<String, String> _cells(int r) {
    final map = <String, String>{};
    for (var c = 0; c < _mapping.length && c < _grid[r].length; c++) {
      final key = _mapping[c];
      if (key != null) map[key] = _grid[r][c].trim();
    }
    return map;
  }

  /// The exact JSON the server will receive — built from the mapping the
  /// pharmacist is looking at, so the preview cannot drift from the payload.
  List<Map<String, dynamic>> _buildRows() {
    final rows = <Map<String, dynamic>>[];
    for (var r = 1; r < _grid.length; r++) {
      final map = _cells(r);
      final name = (map['brandName'] ?? '').trim();
      if (name.isEmpty) continue;
      final type = (map['type'] ?? '').toLowerCase();
      final baseUnit = _typeToBaseUnit.entries
          .firstWhere((e) => type.contains(e.key), orElse: () => const MapEntry('', 'UNIT')).value;
      final gst = _numFrom(map['gst']);
      final mrp = _numFrom(map['mrp']);
      final cost = _numFrom(map['cost']);
      final qty = _numFrom(map['qty'])?.round();
      rows.add({
        'brandName': name,
        if ((map['manufacturer'] ?? '').isNotEmpty) 'manufacturer': map['manufacturer'],
        if ((map['type'] ?? '').isNotEmpty) 'dosageForm': map['type'],
        'baseUnit': baseUnit,
        if ((map['strength'] ?? '').isNotEmpty) 'strength': map['strength'],
        if ((map['scheduleClass'] ?? '').isNotEmpty) 'scheduleClass': map['scheduleClass'],
        if ((map['hsnCode'] ?? '').isNotEmpty) 'hsnCode': map['hsnCode'],
        if (gst != null) 'gstRateBp': (gst * 100).round(),
        if ((map['rackLocation'] ?? '').isNotEmpty) 'rackLocation': map['rackLocation'],
        if (int.tryParse((map['reorderLevel'] ?? '').trim()) != null)
          'reorderLevel': int.parse(map['reorderLevel']!.trim()),
        if ((map['batchNo'] ?? '').isNotEmpty) 'batchNo': map['batchNo'],
        if (_normalizeDate(map['expiry'] ?? '') != null) 'expiryDate': _normalizeDate(map['expiry'] ?? ''),
        if (mrp != null) 'mrpPaise': (mrp * 100).round(),
        if (cost != null) 'purchasePricePaise': (cost * 100).round(),
        if (qty != null && qty > 0) 'openingQty': qty,
      });
    }
    return rows;
  }

  Future<void> _import() async {
    final rows = _buildRows();
    if (rows.isEmpty) {
      setState(() => _error = 'No product rows found — the medicine-name column is empty on every row.');
      return;
    }
    final auth = ref.read(authProvider);
    setState(() { _saving = true; _error = null; });
    try {
      final result = await ref.read(repositoryProvider)
          .importCatalog(auth.tenantPublicId!, auth.token!, rows);
      if (!mounted) return;
      final created = (result['created'] as num?)?.toInt() ?? 0;
      final stocked = (result['stocked'] as num?)?.toInt() ?? 0;
      final updated = (result['updated'] as num?)?.toInt() ?? 0;
      final skipped = (result['skipped'] as num?)?.toInt() ?? 0;
      final errors = ((result['errors'] as List?) ?? const []).map((e) => e.toString()).toList();
      Navigator.pop(context);
      widget.onDone();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$created added, $stocked stocked, $updated updated, $skipped unchanged'
            '${errors.isNotEmpty ? ', ${errors.length} row(s) had problems' : ''}.'),
        backgroundColor: errors.isNotEmpty ? SevaCareColors.warning : SevaCareColors.success,
      ));
      // Row-level problems deserve more than a count — show which rows and why,
      // so the pharmacist can fix the file instead of guessing.
      if (errors.isNotEmpty && mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: SevaCareColors.surface,
            title: const Text('Rows that did not import'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in errors)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('• $e', style: const TextStyle(fontSize: 12.5)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: SevaCareColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            const Text('Import medicines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Pick the supplier\'s price list — .csv, .tsv or .xlsx. '
                'The first row must name the columns.',
                style: TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
            const SizedBox(height: 14),
            if (!_hasFile) ..._sourceStep() else ..._mappingStep(),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SevaCareColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 16, color: SevaCareColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_error!, style: const TextStyle(color: SevaCareColors.error, fontSize: 12.5))),
                ]),
              ),
            ],
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  List<Widget> _sourceStep() => [
        GradientButton(
          label: 'Choose a file',
          icon: Icons.upload_file_outlined,
          fullWidth: true,
          onPressed: _pickFile,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            icon: Icon(_showPaste ? Icons.expand_less : Icons.content_paste, size: 16),
            label: Text(_showPaste ? 'Hide paste box' : 'Or paste the rows instead'),
            onPressed: () => setState(() => _showPaste = !_showPaste),
          ),
        ),
        if (_showPaste) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: SevaCareColors.surfaceMuted, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              'Name, Type, Strength, GST, MRP, Batch, Expiry, Qty\n'
              'Dolo 650, Tablet, 650mg, 12, 2.10, B1234, 2027-06, 200',
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: SevaCareColors.textMuted),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _csvCtrl,
            minLines: 4,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              hintText: 'Paste rows here…',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.table_rows_outlined, size: 18),
            label: const Text('Read these rows'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: _parsePaste,
          ),
        ],
      ];

  List<Widget> _mappingStep() {
    final rows = _buildRows();
    final withStock = rows.where((r) => r.containsKey('openingQty')).length;
    final dupes = _duplicateFields;
    final ready = _nameMapped && dupes.isEmpty && rows.isNotEmpty && _confirmed;

    return [
      // Source
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: SevaCareColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          const Icon(Icons.description_outlined, size: 16, color: SevaCareColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$_sourceName · ${_grid.length - 1} row${_grid.length - 1 == 1 ? '' : 's'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => setState(() {
              _grid = [];
              _mapping = [];
              _sourceName = null;
              _confirmed = false;
            }),
            child: const Text('Change'),
          ),
        ]),
      ),
      const SizedBox(height: 14),

      // Column mapping — one row per column of their file.
      const Text('Check the columns', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 2),
      const Text('This is what each column of your file will become. Fix anything that is wrong — '
          'these values are written straight into your catalog and stock.',
          style: TextStyle(fontSize: 11.5, color: SevaCareColors.textMuted)),
      const SizedBox(height: 10),
      for (var c = 0; c < _grid.first.length; c++) _columnRow(c),

      if (!_nameMapped) ...[
        const SizedBox(height: 8),
        _flag(SevaCareColors.error, Icons.error_outline,
            'No column is mapped to the medicine name. Nothing can be imported without it.'),
      ],
      for (final d in dupes)
        _flag(SevaCareColors.error, Icons.error_outline,
            'Two columns are both mapped to "${_importFields.firstWhere((f) => f.key == d).label}". Pick one.'),

      const SizedBox(height: 14),

      // What will actually be written.
      Text('Preview · ${rows.length} product${rows.length == 1 ? '' : 's'}'
          '${withStock > 0 ? ', $withStock with opening stock' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 6),
      if (rows.isEmpty)
        _flag(SevaCareColors.warning, Icons.warning_amber_outlined,
            'No row has a medicine name — nothing would be imported.')
      else
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: SevaCareColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            for (var i = 0; i < rows.length && i < 5; i++) _previewRow(rows[i], i),
            if (rows.length > 5)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('…and ${rows.length - 5} more',
                    style: const TextStyle(fontSize: 12, color: SevaCareColors.textMuted)),
              ),
          ]),
        ),

      const SizedBox(height: 12),
      CheckboxListTile(
        value: _confirmed,
        onChanged: rows.isEmpty ? null : (v) => setState(() => _confirmed = v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
        title: const Text(
          'I have checked the columns and the preview. The names, prices and quantities are correct.',
          style: TextStyle(fontSize: 12.5),
        ),
      ),
      const SizedBox(height: 8),
      GradientButton(
        label: rows.isEmpty ? 'Import' : 'Import ${rows.length} product${rows.length == 1 ? '' : 's'}',
        icon: Icons.check,
        fullWidth: true,
        isLoading: _saving,
        onPressed: (!ready || _saving) ? null : _import,
      ),
    ];
  }

  Widget _columnRow(int c) {
    final header = _grid.first[c];
    final sample = _grid.length > 1 ? _grid[1][c] : '';
    final value = _mapping[c];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(header.isEmpty ? '(no header)' : header,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(sample.isEmpty ? 'blank' : 'e.g. $sample',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted)),
          ]),
        ),
        Icon(
          value == null ? Icons.block : Icons.arrow_forward,
          size: 14,
          color: value == null ? SevaCareColors.textMuted : SevaCareColors.success,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String?>(
            initialValue: value,
            isDense: true,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Ignore', style: TextStyle(fontSize: 12.5, color: SevaCareColors.textMuted)),
              ),
              for (final f in _importFields)
                DropdownMenuItem<String?>(
                  value: f.key,
                  child: Text(f.label, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() {
              _mapping[c] = v;
              // The mapping changed, so the thing they confirmed no longer exists.
              _confirmed = false;
            }),
          ),
        ),
      ]),
    );
  }

  Widget _previewRow(Map<String, dynamic> r, int i) {
    String money(String key) {
      final p = r[key] as int?;
      return p == null ? '—' : _rupees(p);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: i.isOdd ? SevaCareColors.surfaceMuted.withValues(alpha: 0.5) : null,
      child: Row(children: [
        _MedBadge(dosageForm: r['dosageForm'] as String?, baseUnit: r['baseUnit'] as String?, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['brandName']}${r['strength'] != null ? ' · ${r['strength']}' : ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              [
                'MRP ${money('mrpPaise')}',
                'cost ${money('purchasePricePaise')}',
                if (r['gstRateBp'] != null) 'GST ${(r['gstRateBp'] as int) / 100}%',
                if (r['batchNo'] != null) 'batch ${r['batchNo']}',
                if (r['expiryDate'] != null) 'exp ${r['expiryDate']}',
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: SevaCareColors.textMuted),
            ),
          ]),
        ),
        if (r['openingQty'] != null)
          Text('+${r['openingQty']}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SevaCareColors.success)),
      ]),
    );
  }

  Widget _flag(Color c, IconData icon, String msg) => Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12, color: c))),
        ]),
      );
}
