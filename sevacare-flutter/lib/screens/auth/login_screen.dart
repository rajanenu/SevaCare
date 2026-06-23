import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_utils.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

// Default mobile numbers per role (local dev convenience)
String _defaultMobile(UserRole role) => switch (role) {
      UserRole.patient => '9000000001',
      UserRole.doctor => '9000000002',
      UserRole.admin => '9000000003',
      UserRole.platformAdmin => '9000000999',
    };

// Role description blurbs
String _roleDescription(UserRole role) => switch (role) {
      UserRole.patient =>
        'Book care, manage appointments, and access prescriptions.',
      UserRole.doctor =>
        'Review today\'s list, complete consults, and manage schedules.',
      UserRole.admin =>
        'Manage one hospital: doctors, hospital admins, patients, and reports.',
      UserRole.platformAdmin =>
        'Manage the SevaCare platform, onboard hospitals, and administer platform users.',
    };

// Where to navigate after a successful login
String _routeForRole(UserRole role) => switch (role) {
      UserRole.patient => '/patient',
      UserRole.doctor => '/doctor',
      UserRole.admin => '/admin',
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

  @override
  void initState() {
    super.initState();
    // Always reset to patient on entry (clears stale role from previous hospital visit)
    final startRole = widget.platformAdminMode ? UserRole.platformAdmin : UserRole.patient;
    _mobileCtrl = TextEditingController(text: _defaultMobile(startRole));
    _emailCtrl = TextEditingController();
    _otpCtrl = TextEditingController(text: '0000');
    // Send OTP is enabled from the start — patient tab is pre-selected by default
    _roleSelected = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(activeRoleProvider.notifier).state = startRole;
      ref.read(loginFormProvider.notifier).reset();
    });
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

    final tenantId = role == UserRole.platformAdmin ? 'platform' : hospitalState.tenantPublicId;
    try {
      await ref.read(repositoryProvider).requestOtp(
            OtpRequest(
              tenantPublicId: tenantId,
              role: role.apiValue,
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

    final tenantId = role == UserRole.platformAdmin ? 'platform' : hospitalState.tenantPublicId;
    try {
      final session = await ref.read(repositoryProvider).verifyOtp(
            OtpVerifyRequest(
              tenantPublicId: tenantId,
              role: role.apiValue,
              mobileNumber: mobile,
              otp: otp,
            ),
          );
      await ref.read(authProvider.notifier).setSession(session);
      ref.read(loginMobileProvider.notifier).state = mobile;
      if (mounted) {
        context.go(_routeForRole(role));
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
        SegmentItem(value: UserRole.platformAdmin, label: 'Platform Admin'),
      ];
    }
    return [
      SegmentItem(value: UserRole.patient, label: 'Patient'),
      SegmentItem(value: UserRole.doctor, label: 'Doctor'),
      SegmentItem(value: UserRole.admin, label: 'Hospital Admin'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(activeRoleProvider);
    final formState = ref.watch(loginFormProvider);
    final hospitalState = ref.watch(hospitalProvider);

    return AppShell(
      hospitalName: hospitalState.hospitalName.isNotEmpty
          ? hospitalState.hospitalName
          : 'SevaCare',
      // No role shown in header — persona chip appears after login
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Back button ──────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: BackBtn(
              onPressed: () => context.go('/search'),
            ),
          ),
          const SizedBox(height: 16),
          // ── Page header ──────────────────────────────────────────────────
          PageHeader(
            title: hospitalState.hospitalName.isNotEmpty
                ? hospitalState.hospitalName
                : 'SevaCare',
            subtitle: 'Login to continue',
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
            const SizedBox(height: 20),
          ],
          // ── Login card ───────────────────────────────────────────────────
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card title
                Text(
                  '${role.label} access',
                  style: AppTextStyles.sectionTitle(SevaCareColors.text),
                ),
                const SizedBox(height: 6),
                // Role description
                Text(
                  _roleDescription(role),
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted),
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
                // ── Email field (optional) ───────────────────────────────
                AppFormField(
                  label: 'Email Address',
                  placeholder: 'Optional — enter your email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  required: false,
                  readOnly: formState.otpSent,
                  onChanged: ref.read(loginFormProvider.notifier).setEmail,
                  textInputAction:
                      formState.otpSent ? TextInputAction.next : TextInputAction.done,
                ),
                // ── OTP sent success banner ──────────────────────────────
                if (formState.otpSent) ...[
                  _OtpSentBanner(),
                  const SizedBox(height: 16),
                ],
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
                    onPressed: (formState.sending || !_roleSelected) ? null : _sendOtp,
                  )
                else ...[
                  PrimaryButton(
                    label: 'Continue',
                    isLoading: formState.sending,
                    fullWidth: true,
                    onPressed: formState.sending ? null : _verifyOtp,
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    label: _resendCountdown > 0
                        ? 'Resend in ${_resendCountdown}s'
                        : 'Resend OTP',
                    fullWidth: true,
                    onPressed: (formState.sending || _resendCountdown > 0) ? null : _resendOtp,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── Choose different hospital ────────────────────────────────────
          SecondaryButton(
            label: 'Choose Different Hospital',
            icon: Icons.swap_horiz,
            fullWidth: true,
            onPressed: () => context.go('/search'),
          ),
          const SizedBox(height: 16),
        ],
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
          const Icon(Icons.error_outline, size: 18, color: SevaCareColors.danger),
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
