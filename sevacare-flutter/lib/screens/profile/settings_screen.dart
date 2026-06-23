import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final hospitalName = ref.watch(hospitalProvider).hospitalName;
    final auth = ref.watch(authProvider);
    final isDark = ref.watch(darkModeProvider);

    return AppShell(
      hospitalName: hospitalName,
      role: auth.role,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BackBtn(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 4),
          PageHeader(title: 'Settings', subtitle: 'App preferences & configuration'),
          const SizedBox(height: 16),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Notifications', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  title: Text('Push Notifications', style: AppTextStyles.bodyText(SevaCareColors.text)),
                  subtitle: Text('Appointment reminders & updates', style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                  value: _notificationsEnabled,
                  activeThumbColor: SevaCareColors.primary,
                  activeTrackColor: SevaCareColors.primarySoft,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  title: Text('Dark Mode', style: AppTextStyles.bodyText(SevaCareColors.text)),
                  subtitle: Text('Toggle dark/light theme', style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                  value: isDark,
                  activeThumbColor: SevaCareColors.primary,
                  activeTrackColor: SevaCareColors.primarySoft,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => ref.read(darkModeProvider.notifier).state = v,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App Info', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                const SizedBox(height: 8),
                const InfoRow(label: 'Version', value: '1.0.0'),
                const SectionDivider(),
                const InfoRow(label: 'Environment', value: 'Local'),
                const SectionDivider(),
                const InfoRow(label: 'API', value: 'localhost:8081'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                const SizedBox(height: 8),
                InfoRow(label: 'Role', value: auth.role?.label ?? 'Guest'),
                const SectionDivider(),
                InfoRow(label: 'Tenant', value: auth.tenantPublicId ?? '-'),
                const SectionDivider(),
                InfoRow(label: 'Subject ID', value: auth.subjectPublicId ?? '-'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (auth.isAuthenticated)
            DangerButton(
              label: 'Sign Out',
              onPressed: () => _signOut(context),
              fullWidth: true,
              icon: Icons.logout,
            ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    await ref.read(authProvider.notifier).clearSession();
    if (context.mounted) context.go('/');
  }
}
