import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/biometric_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/app_snack.dart';
import '../../core/utils/error_utils.dart';
import '../../core/utils/mobile_input_formatter.dart';
import '../../core/utils/profile_storage.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// The store account's own profile — deliberately separate from the hospital
/// ProfileScreen, whose bottom navigation and role furniture belong to a
/// hospital. A pharmacy owner or counter staff sees only what is theirs: the
/// person behind the counter, their contacts, and the account controls.
class PharmacyProfileScreen extends ConsumerStatefulWidget {
  const PharmacyProfileScreen({super.key});

  @override
  ConsumerState<PharmacyProfileScreen> createState() => _PharmacyProfileScreenState();
}

class _PharmacyProfileScreenState extends ConsumerState<PharmacyProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _secondaryMobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;

  String _gender = 'male';
  String _bloodGroup = '';
  Uint8List? _photoBytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _secondaryMobileCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _secondaryMobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final auth = ref.read(authProvider);
    final userId = auth.subjectPublicId ?? '';
    final local = await ProfileStorage.load(userId);

    // Backend is authoritative for the account record; local fills the
    // device-only extras (photo, gender, blood group, address).
    try {
      final record = await ref.read(repositoryProvider)
          .getAdminUser(auth.tenantPublicId ?? '', userId, auth.token ?? '');
      _nameCtrl.text = record.fullName.isNotEmpty ? record.fullName : local.name;
      _mobileCtrl.text = record.mobileNumber ?? '';
      _secondaryMobileCtrl.text = record.secondaryMobile ?? '';
      _emailCtrl.text = record.email ?? local.email;
    } catch (_) {
      _nameCtrl.text = local.name;
      _emailCtrl.text = local.email;
    }
    final photoBytes = ProfileStorage.b64ToBytes(local.photoB64);
    if (mounted) {
      setState(() {
        _addressCtrl.text = local.address;
        _gender = local.gender;
        _bloodGroup = local.bloodGroup;
        _photoBytes = photoBytes == null ? null : Uint8List.fromList(photoBytes);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final auth = ref.read(authProvider);
    final userId = auth.subjectPublicId ?? '';
    setState(() { _saving = true; _error = null; });

    await ProfileStorage.save(userId, ProfileData(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      bloodGroup: _bloodGroup,
      photoB64: ProfileStorage.bytesToB64(_photoBytes),
    ));

    try {
      await ref.read(repositoryProvider).updateAdminUser(
        auth.tenantPublicId ?? '', userId, auth.token ?? '',
        AdminUserUpsertRequest(
          fullName: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
          secondaryMobile: _secondaryMobileCtrl.text.trim().isNotEmpty
              ? _secondaryMobileCtrl.text.trim() : null,
        ),
      );
      // Photo syncs to the backend so a reinstall or second device gets it back.
      try {
        await ref.read(repositoryProvider).updateAdminOrStaffPhoto(
            auth.tenantPublicId ?? '', userId, auth.token ?? '',
            ProfileStorage.bytesToB64(_photoBytes));
      } catch (_) {/* photo stays local-only; not worth failing the save */}
      if (mounted) {
        AppSnack.success(context, 'Profile saved.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Saved on this device. Sync failed: ${extractErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final biometricEnabled = await BiometricService.isEnabled();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text('Sign Out', style: AppTextStyles.cardTitle(SevaCareColors.text)),
        content: Text('Are you sure you want to sign out?',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    if (!biometricEnabled) {
      // Full sign-out: revoke server-side too. With biometric kept, the stored
      // session must stay live so the fingerprint can restore it without OTP.
      await ref.read(authProvider.notifier).logoutEverywhere();
    }
    await ref.read(authProvider.notifier).clearSession(wipeStorage: !biometricEnabled);
    if (mounted) context.go('/');
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text('Delete Account', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
        content: Text(
          'This permanently disables your login — you will not be able to sign in '
          'again. The store\'s sales and stock records are not deleted, only your '
          'access. This cannot be undone. Continue?',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final auth = ref.read(authProvider);
    try {
      await ref.read(repositoryProvider).deleteMyAdminOrStaffAccount(
          auth.tenantPublicId ?? '', auth.subjectPublicId ?? '', auth.token ?? '');
      if (!mounted) return;
      // The row is gone but the JWT would verify until expiry — revoke it.
      await ref.read(authProvider.notifier).logoutEverywhere();
      await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, extractErrorMessage(e, fallback: 'Could not delete account.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final shopName = auth.capabilities?.tenantName ?? 'Pharmacy';
    final isOwner = auth.userType == 'ADMIN';

    return AppShell(
      hospitalName: shopName,
      role: auth.role,
      showBackButton: true,
      helpRoute: '/pharmacy/help',
      homeRoute: '/pharmacy',
      onBack: () => context.canPop() ? context.pop() : context.go('/pharmacy'),
      body: _loading
          ? const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              PageHeader(
                title: 'My Profile',
                subtitle: isOwner ? 'Store owner · $shopName' : 'Counter staff · $shopName',
              ),
              const SizedBox(height: 16),

              Center(
                child: ProfileAvatarPicker(
                  initials: _nameCtrl.text.trim().isNotEmpty
                      ? _nameCtrl.text.trim()[0].toUpperCase() : 'P',
                  hue: 160,
                  savedPhotoBytes: _photoBytes,
                  onImageChanged: (bytes) => setState(() => _photoBytes = bytes),
                ),
              ),
              const SizedBox(height: 16),

              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Details', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                  const SizedBox(height: 8),
                  AppFormField(label: 'Name', controller: _nameCtrl, placeholder: 'Your name'),
                  AppFormField(
                    label: 'Mobile (login number)',
                    controller: _mobileCtrl,
                    readOnly: true,
                  ),
                  AppFormField(
                    label: 'Secondary Mobile (optional)',
                    controller: _secondaryMobileCtrl,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [MobileInputFormatter()],
                    placeholder: 'An alternate number',
                  ),
                  AppFormField(
                    label: 'Email',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    placeholder: 'Email address',
                  ),
                  AppFormField(
                    label: 'Address',
                    controller: _addressCtrl,
                    maxLines: 2,
                    placeholder: 'Your address',
                  ),
                  Row(children: [
                    Expanded(
                      child: AppDropdown<String>(
                        label: 'Gender',
                        value: _gender,
                        items: const [
                          DropdownMenuItem(value: 'male', child: Text('Male')),
                          DropdownMenuItem(value: 'female', child: Text('Female')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _gender = v ?? 'male'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppDropdown<String>(
                        label: 'Blood Group',
                        value: _bloodGroup,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Select')),
                          DropdownMenuItem(value: 'A+', child: Text('A+')),
                          DropdownMenuItem(value: 'A-', child: Text('A-')),
                          DropdownMenuItem(value: 'B+', child: Text('B+')),
                          DropdownMenuItem(value: 'B-', child: Text('B-')),
                          DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                          DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                          DropdownMenuItem(value: 'O+', child: Text('O+')),
                          DropdownMenuItem(value: 'O-', child: Text('O-')),
                        ],
                        onChanged: (v) => setState(() => _bloodGroup = v ?? ''),
                      ),
                    ),
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error!, style: const TextStyle(color: SevaCareColors.warning, fontSize: 13)),
                    ),
                  const SizedBox(height: 8),
                  GradientButton(label: 'Save', icon: Icons.check, fullWidth: true,
                      isLoading: _saving, onPressed: _saving ? null : _save),
                ]),
              ),
              const SizedBox(height: 12),

              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('App', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                  const SizedBox(height: 4),
                  // Every counter user can set their own 4-digit login passcode;
                  // once set, the shared default OTP stops working for their number.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.lock_outline, color: SevaCareColors.textMuted),
                    title: Text('Login Passcode', style: AppTextStyles.bodyText(SevaCareColors.text)),
                    trailing: const Icon(Icons.chevron_right, color: SevaCareColors.textMuted),
                    onTap: () async {
                      final saved = await showSetPasscodeSheet(context, ref);
                      if (saved && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Passcode set — use it to sign in from now on.')));
                      }
                    },
                  ),
                  // The owner frees a staff member (or a customer of the same
                  // tenant) who forgot their passcode.
                  if (ref.watch(authProvider).userType == 'ADMIN')
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.lock_reset_outlined, color: SevaCareColors.textMuted),
                      title: Text("Reset a User's Passcode", style: AppTextStyles.bodyText(SevaCareColors.text)),
                      trailing: const Icon(Icons.chevron_right, color: SevaCareColors.textMuted),
                      onTap: () => showResetPasscodeDialog(context, ref, platformWide: false),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.settings_outlined, color: SevaCareColors.textMuted),
                    title: Text('Settings', style: AppTextStyles.bodyText(SevaCareColors.text)),
                    trailing: const Icon(Icons.chevron_right, color: SevaCareColors.textMuted),
                    onTap: () => context.push('/settings'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.help_outline_rounded, color: SevaCareColors.textMuted),
                    title: Text('Help & Support', style: AppTextStyles.bodyText(SevaCareColors.text)),
                    trailing: const Icon(Icons.chevron_right, color: SevaCareColors.textMuted),
                    onTap: () => context.push('/pharmacy/help'),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              DangerButton(label: 'Sign Out', icon: Icons.logout, fullWidth: true, onPressed: _signOut),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, size: 18, color: SevaCareColors.danger),
                label: Text('Delete Account', style: AppTextStyles.label(SevaCareColors.danger)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: SevaCareColors.danger),
                ),
                onPressed: _deleteAccount,
              ),
              const SizedBox(height: 24),
            ]),
    );
  }
}
