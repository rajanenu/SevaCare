import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/biometric_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/role_style.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// Default mobile numbers per role (local dev convenience)
String _defaultMobile(UserRole role) => switch (role) {
  UserRole.patient => '9000000001',
  UserRole.doctor => '9000000002',
  UserRole.admin || UserRole.staff => '9000000003',
  UserRole.platformAdmin => '9000000999',
};

// Role description blurbs — short by design; the icon + card color carry the rest
String _roleDescription(UserRole role) => switch (role) {
  UserRole.patient => 'Book visits & view prescriptions.',
  UserRole.doctor => 'Consult, prescribe & manage your queue.',
  UserRole.admin => 'Run your hospital, staff & reports.',
  UserRole.staff => 'Register patients & book appointments.',
  UserRole.platformAdmin => 'Onboard hospitals & manage the platform.',
};

// Where to navigate after a successful login
String _routeForRole(UserRole role) => switch (role) {
  UserRole.patient => '/patient',
  UserRole.doctor => '/doctor',
  UserRole.admin => '/admin',
  UserRole.staff => '/staff',
  UserRole.platformAdmin => '/platform-admin',
};

class LoginScreen extends ConsumerStatefulWidget {
  /// When true, only the Platform Admin segment is shown and pre-selected.
  final bool platformAdminMode;

  const LoginScreen({super.key, this.platformAdminMode = false});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _otpCtrl;

  bool _roleSelected = false;
  int _resendCountdown = 0;
  bool _isIpStaff = false; // sub-type within Hospital Staff tab

  // Biometric state
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String _biometricLabel = 'Biometric';

  @override
  void initState() {
    super.initState();
    final startRole = widget.platformAdminMode
        ? UserRole.platformAdmin
        : UserRole.patient;
    _mobileCtrl = TextEditingController(text: _defaultMobile(startRole));
    _emailCtrl = TextEditingController();
    _otpCtrl = TextEditingController(text: '0000');
    _roleSelected = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeRoleProvider.notifier).state = startRole;
      ref.read(loginFormProvider.notifier).reset();
      _checkBiometric();
    });
  }

  Future<void> _checkBiometric() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    final label = await BiometricService.biometricLabel();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricEnabled = enabled;
      _biometricLabel = label;
    });
  }

  /// Called after successful OTP verification — offers to enable biometric.
  Future<void> _promptEnableBiometric() async {
    if (!_biometricAvailable || _biometricEnabled) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text(
          'Enable $_biometricLabel?',
          style: AppTextStyles.cardTitle(SevaCareColors.text),
        ),
        content: Text(
          'Use $_biometricLabel to unlock SevaCare next time — '
          'OTP will always be available as a fallback.',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not now',
              style: AppTextStyles.label(SevaCareColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SevaCareColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Enable', style: AppTextStyles.label(Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) await BiometricService.setEnabled(true);
  }

  /// Unlock using stored biometric credentials.
  Future<void> _loginWithBiometric() async {
    final ok = await BiometricService.authenticate(
      reason: 'Unlock SevaCare with $_biometricLabel',
    );
    if (!ok || !mounted) return;

    final restored = await ref.read(authProvider.notifier).restore();
    if (!mounted) return;
    if (restored) {
      final role = ref.read(authProvider).role;
      if (role != null) {
        context.go(_routeForRole(role));
        return;
      }
    }
    // Token was expired or missing — wipe stale storage and disable biometric
    await BiometricService.setEnabled(false);
    await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
    if (!mounted) return;
    setState(() => _biometricEnabled = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Session expired — please log in with OTP. Biometric has been disabled.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // Called when the segmented control switches role
  void _onRoleChanged(UserRole newRole) {
    ref.read(activeRoleProvider.notifier).state = newRole;
    ref.read(loginFormProvider.notifier).reset();
    // Reset OTP field and pre-fill mobile default
    _mobileCtrl.text = _defaultMobile(newRole);
    _emailCtrl.clear();
    _otpCtrl.text = '0000';
    setState(() => _roleSelected = true);
  }

  Future<void> _sendOtp() async {
    final role = ref.read(activeRoleProvider);
    final hospitalState = ref.read(hospitalProvider);
    final notifier = ref.read(loginFormProvider.notifier);
    final mobile = _mobileCtrl.text.trim();

    if (mobile.isEmpty) {
      notifier.setError('Please enter a mobile number.');
      return;
    }

    if (mobile.length != 10) {
      notifier.setError('Please enter a valid 10-digit mobile number.');
      return;
    }

    notifier.setSending(true);
    notifier.setIdentifier(mobile);

    final tenantId = role == UserRole.platformAdmin
        ? 'platform'
        : hospitalState.tenantPublicId;
    // IP-Staff sub-type uses distinct role 'staff' so backend validates against staff-only records
    final effectiveRole = (_isIpStaff && role == UserRole.admin)
        ? 'staff'
        : role.apiValue;
    try {
      await ref
          .read(repositoryProvider)
          .requestOtp(
            OtpRequest(
              tenantPublicId: tenantId,
              role: effectiveRole,
              mobileNumber: mobile,
            ),
          );
      notifier.markOtpSent();
      // Start 120-second countdown for Resend OTP
      setState(() => _resendCountdown = 120);
      _startResendTimer();
    } catch (e) {
      notifier.setError(_friendlyError(e));
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendCountdown > 0) _resendCountdown--;
      });
      return _resendCountdown > 0;
    });
  }

  Future<void> _verifyOtp() async {
    final role = ref.read(activeRoleProvider);
    final hospitalState = ref.read(hospitalProvider);
    final notifier = ref.read(loginFormProvider.notifier);
    final mobile = _mobileCtrl.text.trim();
    final otp = _otpCtrl.text.trim();

    if (otp.isEmpty) {
      notifier.setError('Please enter the OTP sent to your mobile.');
      return;
    }

    notifier.setSending(true);

    final tenantId = role == UserRole.platformAdmin
        ? 'platform'
        : hospitalState.tenantPublicId;
    final effectiveRole = (_isIpStaff && role == UserRole.admin)
        ? 'staff'
        : role.apiValue;
    try {
      final session = await ref
          .read(repositoryProvider)
          .verifyOtp(
            OtpVerifyRequest(
              tenantPublicId: tenantId,
              role: effectiveRole,
              mobileNumber: mobile,
              otp: otp,
            ),
          );
      await ref.read(authProvider.notifier).setSession(session);
      ref.read(loginMobileProvider.notifier).state = mobile;
      if (mounted) {
        await _promptEnableBiometric();
        final sessionRole = ref.read(authProvider).role ?? role;
        if (mounted) context.go(_routeForRole(sessionRole));
      }
    } catch (e) {
      notifier.setError(_friendlyError(e));
    }
  }

  Future<void> _resendOtp() async {
    setState(() => _resendCountdown = 120);
    _startResendTimer();
    ref.read(loginFormProvider.notifier).resetOtp();
    _otpCtrl.text = '0000';
    await _sendOtp();
  }

  String _friendlyError(Object e) {
    // Try to extract the actual backend error message first
    final backendMsg = extractErrorMessage(e, fallback: '');
    if (backendMsg.isNotEmpty) return backendMsg;
    // Fall back to network-level overrides
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot reach the server. Make sure the backend is running.';
    }
    return 'Something went wrong. Please try again.';
  }

  // The role segments shown in the segmented control
  List<SegmentItem<UserRole>> get _segments {
    if (widget.platformAdminMode) {
      return [
        SegmentItem(
          value: UserRole.platformAdmin,
          label: 'Platform Admin',
          icon: UserRole.platformAdmin.icon,
        ),
      ];
    }
    return [
      SegmentItem(
        value: UserRole.patient,
        label: 'Patient',
        icon: UserRole.patient.icon,
      ),
      SegmentItem(
        value: UserRole.doctor,
        label: 'Doctor',
        icon: UserRole.doctor.icon,
      ),
      SegmentItem(
        value: UserRole.admin,
        label: 'Hospital Staff',
        icon: UserRole.admin.icon,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeRoleProvider);
    final formState = ref.watch(loginFormProvider);
    final hospitalState = ref.watch(hospitalProvider);

    final isPlatformAdmin = widget.platformAdminMode;
    final headerName = isPlatformAdmin
        ? 'SevaCare'
        : (hospitalState.hospitalName.isNotEmpty
              ? hospitalState.hospitalName
              : 'SevaCare');

    return AppShell(
      hospitalName: headerName,
      showBackButton: true,
      onBack: () => context.go(isPlatformAdmin ? '/' : '/search'),
      // No role shown in header — persona chip appears after login
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Page header ──────────────────────────────────────────────────
          PageHeader(
            title: isPlatformAdmin ? 'SevaCare Administration' : headerName,
            subtitle: isPlatformAdmin
                ? 'Platform Admin Access'
                : 'Login to continue',
          ),
          const SizedBox(height: 16),
          // ── Role segmented control ───────────────────────────────────────
          if (!widget.platformAdminMode) ...[
            SegmentedControl<UserRole>(
              items: _segments,
              selected: role,
              onChanged: _onRoleChanged,
            ),
            if (!_roleSelected && !widget.platformAdminMode) ...[
              const SizedBox(height: 8),
              Text(
                'Please select your role above to continue',
                style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
            // ── Admin / IP-Staff sub-radio (only when Hospital Staff tab active)
            // Space is always reserved (maintainSize) so switching role tabs
            // doesn't shift the login form up and down.
            const SizedBox(height: 8),
            Visibility(
              visible: role == UserRole.admin,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isIpStaff = false),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Radio<bool>(
                                value: false,
                                groupValue: _isIpStaff,
                                activeColor: SevaCareColors.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (_) =>
                                    setState(() => _isIpStaff = false),
                              ),
                              Icon(
                                UserRole.admin.icon,
                                size: 15,
                                color: UserRole.admin.fgColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Admin',
                                style: AppTextStyles.label(SevaCareColors.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _isIpStaff = true),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            children: [
                              Radio<bool>(
                                value: true,
                                groupValue: _isIpStaff,
                                activeColor: SevaCareColors.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                onChanged: (_) =>
                                    setState(() => _isIpStaff = true),
                              ),
                              Icon(
                                UserRole.staff.icon,
                                size: 15,
                                color: UserRole.staff.fgColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'IP-Staff',
                                style: AppTextStyles.label(SevaCareColors.text),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          // ── Biometric quick-unlock (shown when enabled + token exists) ──
          if (_biometricEnabled && !widget.platformAdminMode) ...[
            _BiometricUnlockCard(
              label: _biometricLabel,
              onTap: _loginWithBiometric,
            ),
            const SizedBox(height: 12),
          ],

          // ── Login card ───────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card header — role icon badge + title, colored per persona
                Builder(
                  builder: (context) {
                    final effectiveRole = (_isIpStaff && role == UserRole.admin)
                        ? UserRole.staff
                        : role;
                    return Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: effectiveRole.bgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            effectiveRole.icon,
                            size: 22,
                            color: effectiveRole.fgColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${effectiveRole.label} access',
                                style: AppTextStyles.sectionTitle(
                                  SevaCareColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _roleDescription(effectiveRole),
                                style: AppTextStyles.label(
                                  SevaCareColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                // ── Mobile number field ──────────────────────────────────
                AppFormField(
                  label: 'Mobile Number',
                  placeholder: 'Enter 10-digit mobile number',
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  required: true,
                  readOnly: formState.otpSent,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: ref.read(loginFormProvider.notifier).setIdentifier,
                  textInputAction: TextInputAction.next,
                ),
                // ── OTP sent success banner ──────────────────────────────
                if (formState.otpSent) ...[
                  _OtpSentBanner(),
                  const SizedBox(height: 16),
                ],
                // ── Email field (optional) ───────────────────────────────
                AppFormField(
                  label: 'Email Address',
                  placeholder: 'Optional — enter your email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  required: false,
                  readOnly: formState.otpSent,
                  onChanged: ref.read(loginFormProvider.notifier).setEmail,
                  textInputAction: formState.otpSent
                      ? TextInputAction.next
                      : TextInputAction.done,
                ),
                // ── OTP input field ──────────────────────────────────────
                if (formState.otpSent)
                  AppFormField(
                    label: 'OTP',
                    placeholder: 'Enter 4-digit code',
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    required: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: ref.read(loginFormProvider.notifier).setOtp,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _verifyOtp,
                  ),
                // ── Error banner ─────────────────────────────────────────
                if (formState.error != null) ...[
                  _ErrorBanner(message: formState.error!),
                  const SizedBox(height: 16),
                ],
                // ── Action buttons ───────────────────────────────────────
                if (!formState.otpSent)
                  PrimaryButton(
                    label: 'Send OTP',
                    isLoading: formState.sending,
                    fullWidth: true,
                    onPressed: (formState.sending || !_roleSelected)
                        ? null
                        : _sendOtp,
                  )
                else ...[
                  PrimaryButton(
                    label: 'Continue',
                    isLoading: formState.sending,
                    fullWidth: true,
                    onPressed: formState.sending ? null : _verifyOtp,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: GestureDetector(
                      onTap: (formState.sending || _resendCountdown > 0)
                          ? null
                          : _resendOtp,
                      child: Text(
                        _resendCountdown > 0
                            ? "Didn't get it? Resend in ${_resendCountdown}s"
                            : 'Resend OTP',
                        style: AppTextStyles.label(
                          _resendCountdown > 0
                              ? SevaCareColors.textMuted
                              : SevaCareColors.primary,
                        ).copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: _resendCountdown > 0
                              ? TextDecoration.none
                              : TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Choose different hospital (hospital login only) ───────────────
          if (!widget.platformAdminMode) ...[
            SecondaryButton(
              label: 'Choose Different Hospital',
              icon: Icons.swap_horiz,
              fullWidth: true,
              onPressed: () => context.go('/search'),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

// ── Biometric Unlock Card ─────────────────────────────────────────────────────

class _BiometricUnlockCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BiometricUnlockCard({required this.label, required this.onTap});

  IconData get _icon {
    if (label == 'Face ID') return Icons.face_retouching_natural_rounded;
    if (label == 'Fingerprint') return Icons.fingerprint_rounded;
    return Icons.lock_open_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Unlock with $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3F39A8), Color(0xFF7C6FE0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            boxShadow: [
              BoxShadow(
                color: SevaCareColors.primary.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(_icon, size: 24, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Unlock',
                      style: AppTextStyles.cardTitle(Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Use $label to sign in instantly',
                      style: AppTextStyles.label(
                        Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white70,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── OTP Sent Banner ────────────────────────────────────────────────────────────

class _OtpSentBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SevaCareColors.mintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: SevaCareColors.mint.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: SevaCareColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'OTP sent to your mobile number',
              style: AppTextStyles.bodyText(SevaCareColors.mintForeground),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error Banner ───────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SevaCareColors.errorSurface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: SevaCareColors.danger.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: SevaCareColors.danger,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodyText(SevaCareColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
