import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/error_utils.dart';
import '../providers/app_state.dart';
import 'app_form_field.dart';
import 'gradient_button.dart';

/// Set or change the signed-in user's 4-digit login passcode.
///
/// Once set, the shared default OTP (0000) stops working for that mobile and
/// the login screen asks for "your passcode" instead of claiming an OTP was
/// sent. [currentCode] pre-fills the verification field (used right after
/// login, when the user just typed their code); when null the sheet asks for
/// it. Returns true if the passcode was saved.
Future<bool> showSetPasscodeSheet(
  BuildContext context,
  WidgetRef ref, {
  String? currentCode,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SevaCareColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      // Keep the fields above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _SetPasscodeForm(ref: ref, prefilledCurrent: currentCode),
    ),
  );
  return saved ?? false;
}

/// The gentle post-login nudge shown while an account still uses the default
/// OTP: dismissible every time, never blocking. [currentCode] is the code the
/// user just logged in with, so "Set now" skips re-asking for it.
Future<void> showPasscodeNudgeSheet(
  BuildContext context,
  WidgetRef ref, {
  required String currentCode,
}) async {
  final setNow = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: SevaCareColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SevaCareColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: SevaCareColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Secure your account',
                      style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Your login still uses the shared default OTP. Set your own '
              '4-digit passcode so only you can sign in with your number.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Set Passcode Now',
              fullWidth: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text('Later',
                    style: AppTextStyles.label(SevaCareColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (setNow == true && context.mounted) {
    final saved =
        await showSetPasscodeSheet(context, ref, currentCode: currentCode);
    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Passcode set — use it to sign in from now on.')));
    }
  }
}

/// Admin tool: clear a user's forgotten passcode so the default OTP applies
/// again. [platformWide] switches between the tenant-scoped admin endpoint and
/// the platform-admin one.
Future<void> showResetPasscodeDialog(
  BuildContext context,
  WidgetRef ref, {
  required bool platformWide,
}) async {
  final mobileCtrl = TextEditingController();
  String? error;
  bool busy = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Reset a user's passcode",
            style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              platformWide
                  ? 'Clears the passcode for any registered mobile number. '
                      'The default OTP works again until they set a new code.'
                  : 'Clears the passcode for a user of this hospital or store. '
                      'The default OTP works again until they set a new code.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 14),
            AppFormField(
              label: 'Mobile Number',
              placeholder: 'Enter 10-digit mobile number',
              controller: mobileCtrl,
              keyboardType: TextInputType.phone,
              required: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: AppTextStyles.label(SevaCareColors.danger)),
            ],
          ],
        ),
        actions: [
          SecondaryButton(
              label: 'Cancel', onPressed: () => Navigator.of(ctx).pop()),
          const SizedBox(width: 8),
          PrimaryButton(
            label: 'Reset',
            isLoading: busy,
            onPressed: busy
                ? null
                : () async {
                    final mobile = mobileCtrl.text.trim();
                    if (mobile.length != 10) {
                      setState(() =>
                          error = 'Enter a valid 10-digit mobile number.');
                      return;
                    }
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final repo = ref.read(repositoryProvider);
                      final auth = ref.read(authProvider);
                      final token = auth.token ?? '';
                      if (platformWide) {
                        await repo.platformResetPasscode(token, mobile);
                      } else {
                        await repo.adminResetPasscode(
                            auth.tenantPublicId ?? '', token, mobile);
                      }
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Passcode cleared — the default OTP works again for that number.')));
                      }
                    } catch (e) {
                      setState(() {
                        busy = false;
                        error = extractErrorMessage(e);
                      });
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

class _SetPasscodeForm extends StatefulWidget {
  final WidgetRef ref;
  final String? prefilledCurrent;

  const _SetPasscodeForm({required this.ref, this.prefilledCurrent});

  @override
  State<_SetPasscodeForm> createState() => _SetPasscodeFormState();
}

class _SetPasscodeFormState extends State<_SetPasscodeForm> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _askCurrent => widget.prefilledCurrent == null;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current =
        _askCurrent ? _currentCtrl.text.trim() : widget.prefilledCurrent!;
    final fresh = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (_askCurrent && current.isEmpty) {
      setState(() => _error = 'Enter your current passcode or OTP.');
      return;
    }
    if (fresh.length != 4 || int.tryParse(fresh) == null) {
      setState(() => _error = 'The new passcode must be exactly 4 digits.');
      return;
    }
    if (fresh == '0000') {
      setState(() =>
          _error = '0000 is the shared default — please choose a different code.');
      return;
    }
    if (fresh != confirm) {
      setState(() => _error = 'The two passcodes don\'t match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = widget.ref.read(authProvider).token ?? '';
      await widget.ref.read(repositoryProvider).changePasscode(token, current, fresh);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = extractErrorMessage(e);
      });
    }
  }

  static final _digits = [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(4),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Login Passcode',
                style: AppTextStyles.sectionTitle(SevaCareColors.text)),
            const SizedBox(height: 6),
            Text(
              'A 4-digit code only you know. After you set it, the default '
              'OTP stops working for your number and you sign in with this '
              'code instead.',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (_askCurrent) ...[
              AppFormField(
                label: 'Current Passcode or OTP',
                placeholder: 'What you sign in with today',
                controller: _currentCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                required: true,
                inputFormatters: _digits,
              ),
              const SizedBox(height: 4),
            ],
            AppFormField(
              label: 'New Passcode',
              placeholder: 'Choose 4 digits (not 0000)',
              controller: _newCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              required: true,
              inputFormatters: _digits,
            ),
            const SizedBox(height: 4),
            AppFormField(
              label: 'Confirm New Passcode',
              placeholder: 'Type it again',
              controller: _confirmCtrl,
              keyboardType: TextInputType.number,
              obscureText: true,
              required: true,
              inputFormatters: _digits,
              onEditingComplete: _save,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTextStyles.label(SevaCareColors.danger)),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Save Passcode',
              fullWidth: true,
              isLoading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel',
                    style: AppTextStyles.label(SevaCareColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
