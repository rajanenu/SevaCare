import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
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
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  bool _saving = false;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _mobileCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  List<BottomNavItem> get _bottomNav => switch (widget.role) {
    UserRole.patient => const [
        BottomNavItem(label: 'Dashboard', icon: Icons.grid_view_rounded, route: '/patient'),
        BottomNavItem(label: 'Booking', icon: Icons.add_circle_outline, route: '/patient/booking'),
        BottomNavItem(label: 'Appointments', icon: Icons.calendar_today_outlined, route: '/patient/appointments'),
        BottomNavItem(label: 'Rx', icon: Icons.medication_outlined, route: '/patient/prescriptions'),
        BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/patient/profile'),
      ],
    UserRole.doctor => const [
        BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/doctor'),
        BottomNavItem(label: 'Consult', icon: Icons.healing, route: '/doctor/consult'),
        BottomNavItem(label: 'Rx', icon: Icons.medication_outlined, route: '/doctor/prescriptions'),
        BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/doctor/profile'),
      ],
    UserRole.admin => const [
        BottomNavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, route: '/admin'),
        BottomNavItem(label: 'Admins', icon: Icons.manage_accounts_outlined, route: '/admin/users'),
        BottomNavItem(label: 'Doctors', icon: Icons.medical_services_outlined, route: '/admin/doctors'),
        BottomNavItem(label: 'Reports', icon: Icons.bar_chart_outlined, route: '/admin/reports'),
        BottomNavItem(label: 'Profile', icon: Icons.person_outline, route: '/admin/profile'),
      ],
    UserRole.platformAdmin => const [],
  };

  int get _navIndex => switch (widget.role) {
    UserRole.patient => 4,
    UserRole.doctor => 3,
    UserRole.admin => 4,
    UserRole.platformAdmin => 0,
  };

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    setState(() { _saving = true; _error = null; _saved = false; });
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() { _saving = false; _saved = true; });
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: SevaCareColors.danger),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await ref.read(authProvider.notifier).clearSession();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hospitalName = ref.watch(hospitalProvider).hospitalName;
    final initials = _nameCtrl.text.isNotEmpty
        ? _nameCtrl.text.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()
        : (auth.subjectPublicId?.substring(0, 2).toUpperCase() ?? 'U');
    final hue = AppAvatar.hueFromString(auth.subjectPublicId ?? '');
    final hasNav = _bottomNav.isNotEmpty;

    return AppShell(
      hospitalName: hospitalName,
      role: widget.role,
      bottomNavItems: hasNav ? _bottomNav : null,
      currentNavIndex: hasNav ? _navIndex : null,
      onNavTap: hasNav ? (i) => context.go(_bottomNav[i].route) : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: 'My Profile', subtitle: widget.role.label),
          const SizedBox(height: 16),

          // Avatar + ID
          Center(
            child: Column(
              children: [
                AppAvatar(initials: initials, size: 72, hue: hue),
                const SizedBox(height: 8),
                Text(auth.subjectPublicId ?? '', style: AppTextStyles.badgeText(SevaCareColors.textMuted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: SevaCareColors.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(widget.role.label, style: AppTextStyles.chipLabel(SevaCareColors.primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Edit form
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personal Information', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                const SizedBox(height: 16),
                if (_error != null)
                  _Banner(text: _error!, isSuccess: false),
                if (_saved)
                  const _Banner(text: 'Profile saved successfully!', isSuccess: true),
                AppFormField(
                  label: 'Full Name',
                  controller: _nameCtrl,
                  placeholder: 'Enter your full name',
                  required: true,
                  onChanged: (_) => setState(() { _saved = false; }),
                ),
                AppFormField(
                  label: 'Mobile Number',
                  controller: _mobileCtrl,
                  keyboardType: TextInputType.phone,
                  placeholder: 'Enter mobile number',
                ),
                AppFormField(
                  label: 'Email Address',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  placeholder: 'Enter email address',
                ),
                AppFormField(
                  label: 'Address',
                  controller: _addressCtrl,
                  placeholder: 'Enter address',
                  maxLines: 2,
                ),
                PrimaryButton(
                  label: 'Save Profile',
                  onPressed: _save,
                  isLoading: _saving,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Settings links
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
                  icon: Icons.lock_outline,
                  label: 'Change PIN',
                  onTap: () {},
                ),
                const SectionDivider(),
                _SettingsTile(
                  icon: Icons.help_outline,
                  label: 'Help & Support',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sign out
          DangerButton(
            label: 'Sign Out',
            onPressed: _signOut,
            fullWidth: true,
            icon: Icons.logout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final bool isSuccess;
  const _Banner({required this.text, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    final bg = isSuccess ? SevaCareColors.mintSoft : SevaCareColors.errorSurface;
    final fg = isSuccess ? SevaCareColors.mintForeground : SevaCareColors.danger;
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
