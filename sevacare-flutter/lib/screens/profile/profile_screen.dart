import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

class ProfileScreen extends ConsumerStatefulWidget {
  final UserRole role;
  const ProfileScreen({super.key, required this.role});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _secondaryMobileCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _ageCtrl;

  late final TextEditingController _experienceCtrl;
  late final TextEditingController _qualificationCtrl;

  String _gender = 'male';
  String _bloodGroup = '';
  String _bookingMode = 'BOTH';
  List<AvailabilityRule> _availabilityRules = AvailabilityRule.defaultRules();
  DoctorRecord? _doctorRecord; // kept to preserve fields this form doesn't edit
  bool _showOptionalFields = false;
  bool _personalInfoExpanded = false; // personal info accordion — closed by default
  bool _availabilityExpanded = false; // availability accordion — closed by default
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  late final TextEditingController _hospitalEmailCtrl;
  bool _hospitalEmailExpanded = false;
  bool _savingHospitalEmail = false;
  bool _hospitalEmailSaved = false;
  String? _hospitalEmailError;

  Uint8List? _profileImageBytes;  // current picked image
  String? _savedPhotoB64;         // stored photo (loaded from prefs)

  @override
  void initState() {
    super.initState();
    _nameCtrl   = TextEditingController();
    _mobileCtrl = TextEditingController(text: ref.read(loginMobileProvider));
    _secondaryMobileCtrl = TextEditingController();
    _emailCtrl  = TextEditingController();
    _addressCtrl = TextEditingController();
    _ageCtrl    = TextEditingController();
    _experienceCtrl = TextEditingController();
    _qualificationCtrl = TextEditingController();
    _hospitalEmailCtrl = TextEditingController();
    _loadProfile();
    if (widget.role == UserRole.admin) _loadHospitalEmail();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _secondaryMobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _ageCtrl.dispose();
    _experienceCtrl.dispose();
    _qualificationCtrl.dispose();
    _hospitalEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHospitalEmail() async {
    final auth = ref.read(authProvider);
    try {
      final repo = ref.read(repositoryProvider);
      final profile = await repo.getHospitalProfile(auth.tenantPublicId ?? '', auth.token ?? '');
      if (mounted) _hospitalEmailCtrl.text = profile.email ?? '';
    } catch (_) {
      // Non-fatal — field just starts blank if this fails.
    }
  }

  Future<void> _saveHospitalEmail() async {
    setState(() { _savingHospitalEmail = true; _hospitalEmailError = null; _hospitalEmailSaved = false; });
    final auth = ref.read(authProvider);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.updateHospitalProfile(
        auth.tenantPublicId ?? '',
        auth.token ?? '',
        _hospitalEmailCtrl.text.trim(),
      );
      if (mounted) setState(() => _hospitalEmailSaved = true);
    } catch (e) {
      if (mounted) {
        setState(() => _hospitalEmailError = extractErrorMessage(e, fallback: 'Could not save hospital email.'));
      }
    } finally {
      if (mounted) setState(() => _savingHospitalEmail = false);
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    final auth = ref.read(authProvider);
    final userId = auth.subjectPublicId ?? '';

    // Always load local prefs first (fast path — photo + bloodGroup only from here)
    var local = await ProfileStorage.load(userId);

    // Photo fallback: if this device has no local copy (reinstall, new
    // device, or first login elsewhere), pull the backend-synced photo and
    // cache it locally so this device doesn't need the network again.
    if ((local.photoB64 == null || local.photoB64!.isEmpty) &&
        widget.role != UserRole.platformAdmin &&
        userId.isNotEmpty) {
      try {
        final repo = ref.read(repositoryProvider);
        final tenantId = auth.tenantPublicId ?? '';
        final token = auth.token ?? '';
        final remotePhoto = switch (widget.role) {
          UserRole.patient => await repo.getPatientPhoto(tenantId, userId, token),
          UserRole.doctor => await repo.getDoctorPhoto(tenantId, userId, token),
          UserRole.admin || UserRole.staff => await repo.getAdminOrStaffPhoto(tenantId, userId, token),
          UserRole.platformAdmin => const PhotoView(),
        };
        if (remotePhoto.photoBase64 != null && remotePhoto.photoBase64!.isNotEmpty) {
          await ProfileStorage.savePhoto(userId, remotePhoto.photoBase64!);
          local = await ProfileStorage.load(userId);
        }
      } catch (_) {
        // Non-fatal — profile still loads without a photo.
      }
    }

    // For patient: also try the backend to get authoritative name/age/gender
    if (widget.role == UserRole.patient) {
      try {
        final repo = ref.read(repositoryProvider);
        final record = await repo.getPatientRecord(
          auth.tenantPublicId ?? '',
          userId,
          auth.token ?? '',
        );
        // Backend wins for core fields
        if (mounted) {
          setState(() {
            _nameCtrl.text   = record.fullName.isNotEmpty ? record.fullName : local.name;
            _mobileCtrl.text = record.mobileNumber.isNotEmpty ? record.mobileNumber : local.email;
            _emailCtrl.text  = record.email ?? local.email;
            _addressCtrl.text = record.address ?? local.address;
            _ageCtrl.text    = record.age != null ? '${record.age}' : local.age;
            _gender          = record.gender ?? local.gender;
            _bloodGroup      = local.bloodGroup;   // backend has no blood group column
            _savedPhotoB64   = local.photoB64;
            _loading = false;
          });
        }
        return;
      } catch (_) {
        // Fall through to local-only load
      }
    }

    // For doctor: also fetch the authoritative record (experience/qualification/booking mode)
    if (widget.role == UserRole.doctor) {
      try {
        final repo = ref.read(repositoryProvider);
        final record = await repo.getDoctorRecord(
          ref.read(authProvider).tenantPublicId ?? '',
          userId,
          ref.read(authProvider).token ?? '',
        );
        if (mounted) {
          setState(() {
            _doctorRecord = record;
            _nameCtrl.text = record.fullName.isNotEmpty ? record.fullName : local.name;
            _mobileCtrl.text = record.mobileNumber?.isNotEmpty == true ? record.mobileNumber! : local.email;
            _addressCtrl.text = record.address ?? local.address;
            _ageCtrl.text = record.age != null ? '${record.age}' : local.age;
            _experienceCtrl.text = record.experienceYears?.toString() ?? '';
            _qualificationCtrl.text = record.qualification ?? '';
            _bookingMode = record.bookingMode;
            _bloodGroup = local.bloodGroup;
            _savedPhotoB64 = local.photoB64;
            _loading = false;
          });
        }
        try {
          final rulesJson = await repo.getDoctorWorkingHours(
            ref.read(authProvider).tenantPublicId ?? '',
            userId,
            ref.read(authProvider).token ?? '',
          );
          if (mounted && rulesJson.isNotEmpty) {
            setState(() {
              _availabilityRules = rulesJson.map(AvailabilityRule.fromJson).toList();
            });
          }
        } catch (_) {
          // Keep the sensible defaults if working hours fail to load.
        }
        return;
      } catch (_) {
        // Fall through to local-only load
      }
    }

    // For admin/staff: also fetch the authoritative record (name/email) —
    // both roles share the same backend admin_user table.
    if (widget.role == UserRole.admin || widget.role == UserRole.staff) {
      try {
        final repo = ref.read(repositoryProvider);
        final record = await repo.getAdminUser(
          auth.tenantPublicId ?? '',
          userId,
          auth.token ?? '',
        );
        if (mounted) {
          setState(() {
            _nameCtrl.text = record.fullName.isNotEmpty ? record.fullName : local.name;
            _emailCtrl.text = record.email ?? local.email;
            // The login identity itself — shown read-only below, never sent back.
            _mobileCtrl.text = record.mobileNumber ?? '';
            _secondaryMobileCtrl.text = record.secondaryMobile ?? '';
            _addressCtrl.text = local.address;
            _gender = local.gender;
            _bloodGroup = local.bloodGroup;
            _savedPhotoB64 = local.photoB64;
            _loading = false;
          });
        }
        return;
      } catch (_) {
        // Fall through to local-only load
      }
    }

    // For platform admin: also fetch the authoritative record (name/email)
    if (widget.role == UserRole.platformAdmin) {
      try {
        final repo = ref.read(repositoryProvider);
        final record = await repo.getPlatformAdminUser(userId, auth.token ?? '');
        if (mounted) {
          setState(() {
            _nameCtrl.text = record.fullName.isNotEmpty ? record.fullName : local.name;
            _emailCtrl.text = record.email ?? local.email;
            _mobileCtrl.text = record.mobileNumber.isNotEmpty ? record.mobileNumber : _mobileCtrl.text;
            _loading = false;
          });
        }
        return;
      } catch (_) {
        // Fall through to local-only load
      }
    }

    // Fallback: use local prefs
    if (mounted) {
      setState(() {
        _nameCtrl.text    = local.name;
        _emailCtrl.text   = local.email;
        _addressCtrl.text = local.address;
        _ageCtrl.text     = local.age;
        _gender           = local.gender;
        _bloodGroup       = local.bloodGroup;
        _savedPhotoB64    = local.photoB64;
        _loading = false;
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }
    if (widget.role == UserRole.doctor) {
      final availabilityError = AvailabilityEditor.validate(_availabilityRules);
      if (availabilityError != null) {
        setState(() => _error = availabilityError);
        return;
      }
    }
    setState(() { _saving = true; _error = null; _saved = false; });

    final auth  = ref.read(authProvider);
    final userId = auth.subjectPublicId ?? '';

    // Photo → base64 → SharedPreferences
    String? photoB64 = _savedPhotoB64;
    if (_profileImageBytes != null) {
      photoB64 = base64Encode(_profileImageBytes!);
      await ProfileStorage.savePhoto(userId, photoB64);
    }

    final data = ProfileData(
      name:       _nameCtrl.text.trim(),
      age:        _ageCtrl.text.trim(),
      gender:     _gender,
      email:      _emailCtrl.text.trim(),
      address:    _addressCtrl.text.trim(),
      bloodGroup: _bloodGroup,
      photoB64:   photoB64,
    );

    // Persist locally for all roles
    await ProfileStorage.save(userId, data);

    // Push photo to the backend too — so a doctor's photo is visible to
    // patients booking on a different device, not just on this one.
    try {
      final repo = ref.read(repositoryProvider);
      final tenantId = auth.tenantPublicId ?? '';
      final token = auth.token ?? '';
      switch (widget.role) {
        case UserRole.patient:
          await repo.updatePatientPhoto(tenantId, userId, token, photoB64);
          break;
        case UserRole.doctor:
          await repo.updateDoctorPhoto(tenantId, userId, token, photoB64);
          if (mounted) ref.invalidate(doctorPhotoProvider(userId));
          break;
        case UserRole.admin:
        case UserRole.staff:
          await repo.updateAdminOrStaffPhoto(tenantId, userId, token, photoB64);
          break;
        case UserRole.platformAdmin:
          break;
      }
    } catch (_) {
      // Non-fatal — photo still persisted locally on this device.
    }

    // For patient: also push to backend
    if (widget.role == UserRole.patient) {
      try {
        final repo = ref.read(repositoryProvider);
        await repo.upsertPatientRecord(
          auth.tenantPublicId ?? '',
          userId,
          auth.token ?? '',
          PatientUpsertRequest(
            fullName:     data.name,
            mobileNumber: _mobileCtrl.text.trim(),
            status:       'active',
            email:        data.email.isNotEmpty ? data.email : null,
            gender:       data.gender,
            age:          data.age.isNotEmpty ? int.tryParse(data.age) : null,
            address:      data.address.isNotEmpty ? data.address : null,
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error  = 'Saved locally. Backend sync failed: ${extractErrorMessage(e)}';
          });
          return;
        }
      }
    }

    // For doctor: also push experience/qualification/booking mode to backend
    if (widget.role == UserRole.doctor) {
      if (_doctorRecord == null) {
        // The authoritative record never loaded (e.g. a transient backend
        // error) — saving now would silently skip the backend sync, leaving
        // the name change stuck on this device only. Surface that instead.
        if (mounted) {
          setState(() {
            _saving = false;
            _error = 'Could not sync to the hospital server — your profile failed to load. Please retry.';
          });
          return;
        }
      } else {
        try {
          final repo = ref.read(repositoryProvider);
          final existing = _doctorRecord!;
          await repo.upsertDoctorRecord(
            auth.tenantPublicId ?? '',
            userId,
            auth.token ?? '',
            DoctorUpsertRequest(
              fullName: data.name,
              specialty: existing.specialty,
              availability: existing.availability,
              fee: existing.fee,
              active: existing.active,
              age: data.age.isNotEmpty ? int.tryParse(data.age) : null,
              address: data.address.isNotEmpty ? data.address : null,
              aboutMe: existing.aboutMe,
              mobileNumber: existing.mobileNumber,
              email: existing.email,
              bookingMode: _bookingMode,
              experienceYears: int.tryParse(_experienceCtrl.text.trim()),
              qualification: _qualificationCtrl.text.trim().isEmpty ? null : _qualificationCtrl.text.trim(),
            ),
          );
        } catch (e) {
          if (mounted) {
            setState(() {
              _saving = false;
              _error  = 'Saved locally. Backend sync failed: ${extractErrorMessage(e)}';
            });
            return;
          }
        }

        try {
          final repo = ref.read(repositoryProvider);
          await repo.updateDoctorWorkingHours(
            auth.tenantPublicId ?? '',
            userId,
            auth.token ?? '',
            _availabilityRules.map((r) => r.toJson()).toList(),
          );
        } catch (e) {
          if (mounted) {
            setState(() {
              _saving = false;
              _error  = 'Saved, but availability failed to sync: ${extractErrorMessage(e)}';
            });
            return;
          }
        }
      }
    }

    // For admin/staff: also push name/email/secondary mobile to the shared
    // admin_user backend record (primary mobile intentionally excluded — it's
    // the login identity).
    if (widget.role == UserRole.admin || widget.role == UserRole.staff) {
      try {
        final repo = ref.read(repositoryProvider);
        await repo.updateAdminUser(
          auth.tenantPublicId ?? '',
          userId,
          auth.token ?? '',
          AdminUserUpsertRequest(
            fullName: data.name,
            email: data.email.isNotEmpty ? data.email : null,
            secondaryMobile: _secondaryMobileCtrl.text.trim().isNotEmpty
                ? _secondaryMobileCtrl.text.trim()
                : null,
          ),
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error  = 'Saved locally. Backend sync failed: ${extractErrorMessage(e)}';
          });
          return;
        }
      }
    }

    // For platform admin: also push name/email to the backend
    if (widget.role == UserRole.platformAdmin) {
      try {
        final repo = ref.read(repositoryProvider);
        await repo.updatePlatformAdminUser(
          userId,
          PlatformAdminUserUpsertRequest(
            fullName: data.name,
            mobileNumber: _mobileCtrl.text.trim(),
            email: data.email.isNotEmpty ? data.email : null,
          ),
          auth.token ?? '',
        );
      } catch (e) {
        if (mounted) {
          setState(() {
            _saving = false;
            _error  = 'Saved locally. Backend sync failed: ${extractErrorMessage(e)}';
          });
          return;
        }
      }
    }

    // Keep the session's cached name in sync so other screens (e.g. the
    // dashboard greeting) reflect the change immediately, not just after
    // the next full login.
    await ref.read(authProvider.notifier).updateSubjectName(data.name);

    if (mounted) {
      setState(() {
        _saving = false;
        _saved  = true;
        _savedPhotoB64 = photoB64;
      });
    }
  }

  // ── Photo pick (used by card camera button) ───────────────────────────────────

  Future<void> _pickImage() async {
    if (kIsWeb) {
      await _pickFromSource(ImageSource.gallery);
      return;
    }
    if (!mounted) return;
    final hasPhoto = _profileImageBytes != null || _savedPhotoB64 != null;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhotoSheet(
        onCamera: () { Navigator.pop(ctx); _pickFromSource(ImageSource.camera); },
        onGallery: () { Navigator.pop(ctx); _pickFromSource(ImageSource.gallery); },
        onRemove: hasPhoto
            ? () {
                Navigator.pop(ctx);
                setState(() { _profileImageBytes = null; _savedPhotoB64 = null; });
              }
            : null,
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      if (mounted) setState(() => _profileImageBytes = bytes);
    } catch (e) {
      if (mounted) {
        AppSnack.error(context, 'Could not pick image: $e');
      }
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final biometricEnabled = await BiometricService.isEnabled();

    if (!mounted) return;

    // When biometric is enabled, offer two choices so the user understands what happens
    if (biometricEnabled) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SevaCareColors.surface,
          title: Text('Sign Out', style: AppTextStyles.cardTitle(SevaCareColors.text)),
          content: Text(
            'Your biometric unlock is active. How would you like to sign out?',
            style: AppTextStyles.bodyText(SevaCareColors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted)),
            ),
            // Soft sign-out: credentials stay → biometric can re-unlock without OTP
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'soft'),
              child: Text('Sign Out', style: AppTextStyles.label(SevaCareColors.primary)),
            ),
            // Hard sign-out: wipes everything, disables biometric
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'hard'),
              style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
              child: const Text('Sign Out & Disable Biometric'),
            ),
          ],
        ),
      );

      if (choice == null || choice == 'cancel' || !mounted) return;

      if (choice == 'hard') {
        await BiometricService.setEnabled(false);
        await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
      } else {
        // Soft: clear in-memory state, keep encrypted credentials for biometric
        await ref.read(authProvider.notifier).clearSession(wipeStorage: false);
      }
    } else {
      // No biometric — standard confirm dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: SevaCareColors.surface,
          title: Text('Sign Out', style: AppTextStyles.cardTitle(SevaCareColors.text)),
          content: Text('Are you sure you want to sign out?',
              style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
      await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
    }

    if (mounted) context.go('/');
  }

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        title: Text('Delete Account', style: AppTextStyles.cardTitle(SevaCareColors.danger)),
        content: Text(
          'This permanently disables your account — you will not be able to log '
          'in again. This cannot be undone. Your existing appointments, '
          'prescriptions and records are not deleted, only your login access. '
          'Are you sure you want to continue?',
          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
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
    final repo = ref.read(repositoryProvider);
    final tenantId = auth.tenantPublicId ?? '';
    final userId = auth.subjectPublicId ?? '';
    final token = auth.token ?? '';

    try {
      switch (widget.role) {
        case UserRole.patient:
          await repo.deleteMyPatientAccount(tenantId, userId, token);
          break;
        case UserRole.doctor:
          await repo.deleteMyDoctorAccount(tenantId, userId, token);
          break;
        case UserRole.admin:
        case UserRole.staff:
          await repo.deleteMyAdminOrStaffAccount(tenantId, userId, token);
          break;
        case UserRole.platformAdmin:
          await repo.deleteMyPlatformAdminAccount(userId, token);
          break;
      }
      if (!mounted) return;
      await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        AppSnack.error(
            context, extractErrorMessage(e, fallback: 'Could not delete account.'));
      }
    }
  }

  // ── Bottom nav ────────────────────────────────────────────────────────────────

  List<BottomNavItem> get _bottomNav => switch (widget.role) {
    UserRole.patient => const [
      BottomNavItem(label: 'Dashboard', icon: Icons.grid_view_rounded,        route: '/patient'),
      BottomNavItem(label: 'Doctors',   icon: Icons.people_outline,           route: '/patient/doctors'),
      BottomNavItem(label: 'Appointments', icon: Icons.calendar_today_outlined, route: '/patient/appointments'),
      BottomNavItem(label: 'Rx',        icon: Icons.medication_outlined,      route: '/patient/prescriptions'),
      BottomNavItem(label: 'Profile',   icon: Icons.person_outline,           route: '/patient/profile'),
    ],
    UserRole.doctor => const [
      BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined,       route: '/doctor'),
      BottomNavItem(label: 'Consult',   icon: Icons.healing,                  route: '/doctor/consult'),
      BottomNavItem(label: 'Requests',  icon: Icons.inbox_outlined,           route: '/doctor/requests'),
      BottomNavItem(label: 'Rx',        icon: Icons.medication_outlined,      route: '/doctor/prescriptions'),
      BottomNavItem(label: 'Profile',   icon: Icons.person_outline,           route: '/doctor/profile'),
    ],
    UserRole.admin => const [
      BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined,       route: '/admin'),
      BottomNavItem(label: 'Admins',    icon: Icons.manage_accounts_outlined, route: '/admin/users'),
      BottomNavItem(label: 'Doctors',   icon: Icons.medical_services_outlined, route: '/admin/doctors'),
      BottomNavItem(label: 'Reports',   icon: Icons.bar_chart_outlined,       route: '/admin/reports'),
      BottomNavItem(label: 'Profile',   icon: Icons.person_outline,           route: '/admin/profile'),
    ],
    UserRole.staff => const [
      BottomNavItem(label: 'Portal',   icon: Icons.dashboard_outlined,  route: '/staff'),
      BottomNavItem(label: 'Profile',  icon: Icons.person_outline,      route: '/staff/profile'),
    ],
    UserRole.platformAdmin => const [],
  };

  int get _navIndex => switch (widget.role) {
    UserRole.patient       => 4,
    UserRole.doctor        => 4,
    UserRole.admin         => 4,
    UserRole.staff         => 1,
    UserRole.platformAdmin => 0,
  };

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth         = ref.watch(authProvider);
    final hospitalName = ref.watch(hospitalProvider).hospitalName;
    final hasNav       = _bottomNav.isNotEmpty;

    final Uint8List? displayPhotoBytes = _profileImageBytes
        ?? (_savedPhotoB64 != null ? Uint8List.fromList(base64Decode(_savedPhotoB64!)) : null);

    return AppShell(
      hospitalName: hospitalName,
      role: widget.role,
      bottomNavItems: hasNav ? _bottomNav : null,
      currentNavIndex: hasNav ? _navIndex : null,
      onNavTap: hasNav ? (i) => context.go(_bottomNav[i].route) : null,
      // Roles with bottom-nav reach Profile as a nav destination (no back
      // button needed). Platform admin has no bottom nav — Profile is a
      // pushed sub-page, so it needs an explicit way back (web has no
      // hardware back button the way mobile does).
      showBackButton: !hasNav,
      onBack: hasNav
          ? null
          : () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/platform-admin');
              }
            },
      body: _loading
          ? const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: 'My Profile'),
                const SizedBox(height: 16),

                // ── Patient Health Card ──────────────────────────────────────
                if (widget.role == UserRole.patient) ...[
                  HealthCardWidget(
                    patientId:        auth.subjectPublicId ?? '',
                    name:             _nameCtrl.text,
                    mobile:           _mobileCtrl.text,
                    gender:           _gender,
                    age:              _ageCtrl.text,
                    bloodGroup:       _bloodGroup,
                    hospitalName:     hospitalName,
                    photoBytes:       displayPhotoBytes,
                    onCameraPressed:  _pickImage,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Doctor Card ──────────────────────────────────────────────
                if (widget.role == UserRole.doctor) ...[
                  DoctorCardWidget(
                    doctorId:         auth.subjectPublicId ?? '',
                    name:             _nameCtrl.text,
                    mobile:           _mobileCtrl.text,
                    hospitalName:     hospitalName,
                    photoBytes:       displayPhotoBytes,
                    onCameraPressed:  _pickImage,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Admin / Staff Card ───────────────────────────────────────
                if (widget.role == UserRole.admin || widget.role == UserRole.staff) ...[
                  StaffCardWidget(
                    userId:           auth.subjectPublicId ?? '',
                    name:             _nameCtrl.text.isNotEmpty ? _nameCtrl.text : auth.subjectName,
                    mobile:           _mobileCtrl.text,
                    hospitalName:     hospitalName,
                    isStaff:          widget.role == UserRole.staff,
                    bloodGroup:       _bloodGroup,
                    photoBytes:       displayPhotoBytes,
                    onCameraPressed:  _pickImage,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Hospital Support Email (admin only) ───────────────────────
                if (widget.role == UserRole.admin) ...[
                  _AccordionCard(
                    title: 'Hospital Support Email',
                    expanded: _hospitalEmailExpanded,
                    onToggle: () => setState(() => _hospitalEmailExpanded = !_hospitalEmailExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_hospitalEmailError != null) _Banner(text: _hospitalEmailError!, isSuccess: false),
                        if (_hospitalEmailSaved) const _Banner(text: 'Saved!', isSuccess: true),
                        Text(
                          'Shown to platform support for this hospital. Separate from your own personal login email.',
                          style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        AppFormField(
                          label: 'Hospital Support Email',
                          controller: _hospitalEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          placeholder: 'support@yourhospital.com',
                          onChanged: (_) => setState(() => _hospitalEmailSaved = false),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: _savingHospitalEmail ? 'Saving…' : 'Save Hospital Email',
                          onPressed: _savingHospitalEmail ? null : _saveHospitalEmail,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Personal Information (accordion) ─────────────────────────
                _AccordionCard(
                  title: 'Personal Information',
                  expanded: _personalInfoExpanded,
                  onToggle: () => setState(() => _personalInfoExpanded = !_personalInfoExpanded),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) _Banner(text: _error!, isSuccess: false),
                      if (_saved) const _Banner(text: 'Saved!', isSuccess: true),

                      AppFormField(
                        label: 'Full Name',
                        controller: _nameCtrl,
                        placeholder: 'Your full name',
                        required: true,
                        onChanged: (_) => setState(() => _saved = false),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppDropdown<String>(
                              label: 'Gender',
                              value: _gender,
                              items: const [
                                DropdownMenuItem(value: 'male',   child: Text('Male')),
                                DropdownMenuItem(value: 'female', child: Text('Female')),
                                DropdownMenuItem(value: 'other',  child: Text('Other')),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() { _gender = v; _saved = false; });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: AppFormField(
                              label: 'Age',
                              controller: _ageCtrl,
                              keyboardType: TextInputType.number,
                              placeholder: '25',
                              onChanged: (_) => setState(() => _saved = false),
                            ),
                          ),
                        ],
                      ),
                      AppFormField(
                        label: 'Mobile',
                        controller: _mobileCtrl,
                        keyboardType: TextInputType.phone,
                        placeholder: 'Mobile number',
                        // Admin/staff log in with this number — changing it here
                        // would break OTP sign-in, so it's shown, not editable.
                        readOnly: widget.role == UserRole.admin || widget.role == UserRole.staff,
                      ),
                      if (widget.role == UserRole.admin || widget.role == UserRole.staff)
                        AppFormField(
                          label: 'Secondary Mobile (optional)',
                          controller: _secondaryMobileCtrl,
                          keyboardType: TextInputType.phone,
                          placeholder: 'An alternate number, if you have one',
                          inputFormatters: [MobileInputFormatter()],
                          onChanged: (_) => setState(() => _saved = false),
                        ),
                      if (widget.role == UserRole.doctor) ...[
                        AppFormField(
                          label: 'Years of Experience',
                          controller: _experienceCtrl,
                          keyboardType: TextInputType.number,
                          placeholder: 'e.g. 10',
                          onChanged: (_) => setState(() => _saved = false),
                        ),
                        AppFormField(
                          label: 'Qualification',
                          controller: _qualificationCtrl,
                          placeholder: 'e.g. MS Cardiology, USA',
                          onChanged: (_) => setState(() => _saved = false),
                        ),
                      ],
                      GestureDetector(
                        onTap: () => setState(() => _showOptionalFields = !_showOptionalFields),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _showOptionalFields ? Icons.expand_less : Icons.expand_more,
                                size: 18, color: SevaCareColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text('More Info', style: AppTextStyles.label(SevaCareColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      if (_showOptionalFields) ...[
                        AppFormField(
                          label: 'Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          placeholder: 'Email address',
                          onChanged: (_) => setState(() => _saved = false),
                        ),
                        AppFormField(
                          label: 'Address',
                          controller: _addressCtrl,
                          placeholder: 'Your address',
                          maxLines: 2,
                          onChanged: (_) => setState(() => _saved = false),
                        ),
                        if (widget.role == UserRole.patient ||
                            widget.role == UserRole.staff ||
                            widget.role == UserRole.admin)
                          AppDropdown<String>(
                            label: 'Blood Group',
                            value: _bloodGroup,
                            items: const [
                              DropdownMenuItem(value: '',    child: Text('Select')),
                              DropdownMenuItem(value: 'A+',  child: Text('A+')),
                              DropdownMenuItem(value: 'A-',  child: Text('A-')),
                              DropdownMenuItem(value: 'B+',  child: Text('B+')),
                              DropdownMenuItem(value: 'B-',  child: Text('B-')),
                              DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                              DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                              DropdownMenuItem(value: 'O+',  child: Text('O+')),
                              DropdownMenuItem(value: 'O-',  child: Text('O-')),
                            ],
                            onChanged: (v) => setState(() { _bloodGroup = v ?? ''; _saved = false; }),
                          ),
                      ],
                      const SizedBox(height: 4),
                      PrimaryButton(
                        label: 'Save',
                        onPressed: _save,
                        isLoading: _saving,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Availability (own accordion, closed by default) ───────────
                // Working hours are a long form. Folding them into Personal
                // Information made the profile screen feel like a wall of
                // controls, so they get their own collapsed section and their
                // own Save — which is the same _save() the profile card uses.
                if (widget.role == UserRole.doctor) ...[
                  _AccordionCard(
                    title: 'Availability & Booking Mode',
                    expanded: _availabilityExpanded,
                    onToggle: () => setState(() => _availabilityExpanded = !_availabilityExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Set when you take consultations, and how patients can book (slot, token, or both).',
                          style: AppTextStyles.label(SevaCareColors.textMuted),
                        ),
                        const SizedBox(height: 10),
                        AppDropdown<String>(
                          label: 'Booking Mode',
                          value: _bookingMode,
                          items: const [
                            DropdownMenuItem(value: 'BOTH', child: Text('Slot + Token')),
                            DropdownMenuItem(value: 'SLOT', child: Text('Slot only')),
                            DropdownMenuItem(value: 'TOKEN', child: Text('Token only')),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() { _bookingMode = v; _saved = false; });
                          },
                        ),
                        const SizedBox(height: 8),
                        AvailabilityEditor(
                          initialRules: _availabilityRules,
                          onChanged: (rules) => setState(() {
                            _availabilityRules = rules;
                            _saved = false;
                          }),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Save Availability',
                          onPressed: _save,
                          isLoading: _saving,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Settings ─────────────────────────────────────────────────
                AppCard(
                  child: Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        onTap: () => context.push('/settings'),
                      ),
                      const SectionDivider(),
                      _SettingsTile(
                        icon: Icons.help_outline,
                        label: 'Help & Support',
                        onTap: () => context.go('/help'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                DangerButton(
                  label: 'Sign Out',
                  onPressed: _signOut,
                  fullWidth: true,
                  icon: Icons.logout,
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_outlined, size: 18, color: SevaCareColors.danger),
                    label: Text('Delete Account', style: AppTextStyles.label(SevaCareColors.danger)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }
}

// ── Accordion card ─────────────────────────────────────────────────────────────

class _AccordionCard extends StatelessWidget {
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  const _AccordionCard({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: SevaCareColors.textMuted, size: 22),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

// ── Photo picker bottom sheet ──────────────────────────────────────────────────

class _PhotoSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;

  const _PhotoSheet({
    required this.onCamera,
    required this.onGallery,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E3F0),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Profile Photo',
                style: AppTextStyles.sectionTitle(SevaCareColors.text)),
          ),
          const SizedBox(height: 12),
          _SheetTile(icon: Icons.camera_alt_outlined, label: 'Camera', onTap: onCamera),
          _SheetTile(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: onGallery),
          if (onRemove != null)
            _SheetTile(
              icon: Icons.delete_outline,
              label: 'Remove photo',
              onTap: onRemove!,
              color: SevaCareColors.danger,
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SheetTile({
    required this.icon, required this.label, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? SevaCareColors.text;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: c),
            const SizedBox(width: 16),
            Text(label, style: AppTextStyles.bodyText(c)),
          ],
        ),
      ),
    );
  }
}

// ── Banner ─────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String text;
  final bool isSuccess;
  const _Banner({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final bg   = isSuccess ? SevaCareColors.mintSoft    : SevaCareColors.errorSurface;
    final fg   = isSuccess ? SevaCareColors.mintForeground : SevaCareColors.danger;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodyText(fg))),
        ],
      ),
    );
  }
}

// ── Settings tile ──────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: SevaCareColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.bodyText(SevaCareColors.text))),
            Icon(Icons.chevron_right, size: 18, color: SevaCareColors.textMuted),
          ],
        ),
      ),
    );
  }
}
