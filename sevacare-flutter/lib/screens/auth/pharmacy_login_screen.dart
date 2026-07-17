import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/passcode_sheet.dart';

/// The standalone medical store's sign-in — deliberately its own screen, its own
/// look, its own flow, separate from the hospital login. A shopkeeper types their
/// mobile number and nothing else: the backend finds which store that number
/// runs. One store → straight to the OTP; several → pick one first. On success we
/// land on the counter (`/pharmacy`).
///
/// Green/teal identity throughout so it reads as "your shop", not "a hospital".
///
/// Reached either bare (`/pharmacy-login`) or with a [store] already chosen from
/// Search Pharmacies — the same two doors a hospital login has. With a [store] the
/// screen names the shop and, once the mobile resolves, skips the "which shop?"
/// step; a mobile that doesn't run that shop is told so plainly.
class PharmacyLoginScreen extends ConsumerStatefulWidget {
  final TenantSummary? store;

  const PharmacyLoginScreen({super.key, this.store});

  @override
  ConsumerState<PharmacyLoginScreen> createState() => _PharmacyLoginScreenState();
}

enum _Step { mobile, pickShop, otp }

class _PharmacyLoginScreenState extends ConsumerState<PharmacyLoginScreen> {
  // Pharmacy brand gradient — green to teal, distinct from the hospital purple.
  static const List<Color> _brand = [Color(0xFF15A66A), Color(0xFF0E9488)];
  static const Color _accent = Color(0xFF15A66A);

  final _mobileCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _otpFocus = FocusNode();

  _Step _step = _Step.mobile;
  List<PharmacyLoginOption> _shops = [];
  PharmacyLoginOption? _selected;
  bool _loading = false;
  String? _error;

  /// True when this mobile set its own passcode — the code step then asks for
  /// "your passcode" instead of claiming an OTP was sent (none ever is).
  bool _usesPasscode = false;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  /// The OTP field is built only once we reach that step — focus it on the
  /// frame after it appears so the shopkeeper types the code without a tap.
  void _focusOtpSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _step == _Step.otp) _otpFocus.requestFocus();
    });
  }

  Future<void> _continue() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length != 10) {
      setState(() => _error = 'Enter your 10-digit mobile number.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ref.read(repositoryProvider).pharmacyRequestOtp(mobile);
      if (!mounted) return;
      _usesPasscode = res.usesPasscode;

      // Arrived from Search Pharmacies: the shop is already chosen, so the only
      // question left is whether this mobile actually runs it.
      final picked = widget.store;
      if (picked != null) {
        final match = res.shops
            .where((s) => s.tenantPublicId == picked.tenantPublicId)
            .firstOrNull;
        if (match == null) {
          setState(() => _error =
              'That mobile number isn\'t registered to ${picked.hospitalName}.');
          return;
        }
        setState(() {
          _shops = res.shops;
          _selected = match;
          _step = _Step.otp;
        });
        _focusOtpSoon();
        return;
      }

      setState(() {
        _shops = res.shops;
        if (res.shops.length == 1) {
          _selected = res.shops.first;
          _step = _Step.otp;
        } else {
          _step = _Step.pickShop;
        }
      });
      if (_step == _Step.otp) _focusOtpSoon();
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pickShop(PharmacyLoginOption shop) {
    setState(() {
      _selected = shop;
      _step = _Step.otp;
      _error = null;
    });
    _focusOtpSoon();
  }

  Future<void> _signIn() async {
    final otp = _otpCtrl.text.trim();
    final shop = _selected;
    if (shop == null) return;
    if (otp.isEmpty) {
      setState(() => _error = _usesPasscode
          ? 'Enter your 4-digit passcode.'
          : 'Enter the 4-digit OTP.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(repositoryProvider);
      final session = await repo.pharmacyVerify(_mobileCtrl.text.trim(), otp, shop.tenantPublicId);
      await ref.read(authProvider.notifier).setSession(session);
      // Signed in at the pharmacy door — persist it so a cold restart (which drops
      // capabilities) restores the counter, not the hospital dashboard, even for an
      // owner whose tenant also has a clinical side.
      await ref.read(authProvider.notifier).setHomePreference(true);
      // Load capabilities so the counter names the shop and the shell knows it's
      // pharmacy-only; a failure here is non-fatal — the counter still opens.
      try {
        final caps = await repo.getCapabilities(session.tenantPublicId, session.token);
        ref.read(authProvider.notifier).setCapabilities(caps);
      } catch (_) {/* counter opens with default name */}
      // Still on the shared default OTP: nudge (never force) the owner to set
      // their own passcode while the code they just typed is at hand.
      if (mounted && !_usesPasscode) {
        await showPasscodeNudgeSheet(context, ref, currentCode: otp);
      }
      if (mounted) context.go('/pharmacy');
    } catch (e) {
      if (mounted) setState(() => _error = extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _backToMobile() {
    setState(() {
      _step = _Step.mobile;
      _shops = [];
      _selected = null;
      _otpCtrl.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: 22),
                  _card(),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    // Back means "undo the last step you took": the store list if
                    // that's where you came from, otherwise the home screen.
                    onPressed: () => context.go(
                        widget.store == null ? '/' : '/pharmacy-search'),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: Text(widget.store == null
                        ? 'Back to SevaCare'
                        : 'Choose another pharmacy'),
                    style: TextButton.styleFrom(foregroundColor: SevaCareColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _brand, begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: _brand.first.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
          ),
          child: const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 38),
        ),
        const SizedBox(height: 16),
        Text(widget.store?.hospitalName ?? 'Your Medical Store',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: SevaCareColors.text)),
        const SizedBox(height: 4),
        Text(
            widget.store == null
                ? 'Sign in to run your counter — sell, stock and day-close.'
                : '${widget.store!.city} · Sign in to run your counter.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SevaCareColors.textMuted, fontSize: 14)),
      ],
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SevaCareColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SevaCareColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (_step) {
            _Step.mobile => _mobileStep(),
            _Step.pickShop => _pickShopStep(),
            _Step.otp => _otpStep(),
          },
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 18, color: SevaCareColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: SevaCareColors.error, fontSize: 13))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Mobile number'),
        const SizedBox(height: 8),
        TextField(
          controller: _mobileCtrl,
          autofocus: true,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _continue(),
          decoration: _fieldDecoration('Registered store mobile', Icons.phone_outlined, counter: true),
        ),
        const SizedBox(height: 6),
        Text('Use the number your store was registered with.',
            style: TextStyle(color: SevaCareColors.textMuted, fontSize: 12)),
        const SizedBox(height: 16),
        _brandButton('Continue', Icons.arrow_forward, _loading ? null : _continue),
      ],
    );
  }

  Widget _pickShopStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          _label('Choose your store'),
          const Spacer(),
          TextButton(onPressed: _backToMobile, child: const Text('Change number')),
        ]),
        const SizedBox(height: 4),
        for (final s in _shops)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => _pickShop(s),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: SevaCareColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SevaCareColors.border),
                ),
                child: Row(children: [
                  const Icon(Icons.storefront_outlined, color: _accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.shopName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(s.userType == 'STAFF' ? 'Counter staff' : 'Owner',
                          style: TextStyle(color: SevaCareColors.textMuted, fontSize: 12)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: SevaCareColors.textMuted),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _otpStep() {
    final shop = _selected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (shop != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: SevaCareColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Icon(Icons.storefront_rounded, size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(child: Text(shop.shopName, style: const TextStyle(fontWeight: FontWeight.w700))),
              TextButton(onPressed: _backToMobile, child: const Text('Change')),
            ]),
          ),
        _label(_usesPasscode ? 'Enter your passcode' : 'Enter OTP'),
        const SizedBox(height: 8),
        TextField(
          controller: _otpCtrl,
          focusNode: _otpFocus,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (_) => _signIn(),
          // No hint at what the code is: a login screen that tells the world the
          // OTP is not a login screen. The code itself is unchanged.
          decoration: _fieldDecoration(
              _usesPasscode ? 'Your 4-digit passcode' : '4-digit code',
              Icons.lock_outline,
              counter: true),
        ),
        const SizedBox(height: 10),
        _brandButton('Sign In', Icons.check, _loading ? null : _signIn),
      ],
    );
  }

  Widget _label(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));

  InputDecoration _fieldDecoration(String hint, IconData icon, {bool counter = false}) => InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: SevaCareColors.textMuted),
        counterText: counter ? '' : null,
        filled: true,
        fillColor: SevaCareColors.surfaceMuted,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: SevaCareColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 1.5)),
      );

  Widget _brandButton(String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.7 : 1,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: _brand, begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _brand.first.withValues(alpha: 0.32), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: _loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(width: 8),
                    Icon(icon, color: Colors.white, size: 18),
                  ]),
          ),
        ),
      ),
    );
  }
}
