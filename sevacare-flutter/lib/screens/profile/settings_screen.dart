import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/i18n/i18n.dart';
import '../../core/services/biometric_service.dart';
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
    final themeChoice = ref.watch(themeModeProvider);

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
                Text('Notifications', style: AppTextStyles.sectionTitle(context.colors.text)),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  title: Text('Push Notifications', style: AppTextStyles.bodyText(context.colors.text)),
                  subtitle: Text('Appointment reminders & updates', style: AppTextStyles.bodyText(context.colors.textMuted)),
                  value: _notificationsEnabled,
                  activeThumbColor: context.colors.primary,
                  activeTrackColor: context.colors.primarySoft,
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
                Text('Appearance', style: AppTextStyles.sectionTitle(context.colors.text)),
                const SizedBox(height: 2),
                Text('Choose how SevaCare looks',
                    style: AppTextStyles.bodyText(context.colors.textMuted)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final choice in AppThemeChoice.values)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              left: choice == AppThemeChoice.values.first ? 0 : 8),
                          child: _ThemeChoiceChip(
                            choice: choice,
                            selected: themeChoice == choice,
                            onTap: () => ref
                                .read(themeModeProvider.notifier)
                                .setChoice(choice),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Language ───────────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.translate_rounded,
                        size: 18, color: context.colors.primary),
                    const SizedBox(width: 8),
                    Text(tr(ref, 'Language'),
                        style: AppTextStyles.sectionTitle(context.colors.text)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tr(ref, 'Choose your language'),
                  style: AppTextStyles.bodyText(context.colors.textMuted),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppLanguage.values.map((lang) {
                    final selected = ref.watch(languageProvider) == lang;
                    return GestureDetector(
                      onTap: () =>
                          ref.read(languageProvider.notifier).setLanguage(lang),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? context.colors.primary
                              : context.colors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? context.colors.primary
                                : context.colors.border,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lang.nativeName,
                              style: AppTextStyles.body(
                                size: 13,
                                weight: FontWeight.w600,
                                color: selected
                                    ? context.colors.textOnPrimary
                                    : context.colors.text,
                              ),
                            ),
                            if (lang != AppLanguage.en)
                              Text(
                                lang.englishName,
                                style: AppTextStyles.label(
                                  selected
                                      ? context.colors.textOnPrimary
                                          .withValues(alpha: 0.75)
                                      : context.colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App Info', style: AppTextStyles.sectionTitle(context.colors.text)),
                const SizedBox(height: 8),
                const InfoRow(label: 'Version', value: '1.0.0'),
                const SectionDivider(),
                const InfoRow(label: 'Environment', value: 'Local'),
                const SectionDivider(),
                InfoRow(label: 'API', value: AppConfig.apiBaseUrl),
              ],
            ),
          ),
          const SizedBox(height: 12),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account', style: AppTextStyles.sectionTitle(context.colors.text)),
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
    final biometricEnabled = await BiometricService.isEnabled();
    if (!context.mounted) return;

    if (biometricEnabled) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Sign Out', style: AppTextStyles.cardTitle(context.colors.text)),
          content: Text(
            'Your biometric unlock is active. How would you like to sign out?',
            style: AppTextStyles.bodyText(context.colors.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Cancel', style: AppTextStyles.label(context.colors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'soft'),
              child: Text('Sign Out', style: AppTextStyles.label(context.colors.primary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'hard'),
              style: TextButton.styleFrom(foregroundColor: context.colors.danger),
              child: const Text('Sign Out & Disable Biometric'),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel' || !context.mounted) return;
      if (choice == 'hard') {
        await BiometricService.setEnabled(false);
        await ref.read(authProvider.notifier).logoutEverywhere();
        await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
      } else {
        // Soft sign-out keeps the stored session live for biometric restore —
        // no server-side revocation, or the fingerprint would unlock a corpse.
        await ref.read(authProvider.notifier).clearSession(wipeStorage: false);
      }
    } else {
      await ref.read(authProvider.notifier).logoutEverywhere();
      await ref.read(authProvider.notifier).clearSession(wipeStorage: true);
    }

    if (context.mounted) context.go('/');
  }
}

/// A single System/Light/Dark option in the Appearance selector.
class _ThemeChoiceChip extends StatelessWidget {
  final AppThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeChoiceChip({
    required this.choice,
    required this.selected,
    required this.onTap,
  });

  (IconData, String) get _config => switch (choice) {
        AppThemeChoice.system => (Icons.brightness_auto_rounded, 'System'),
        AppThemeChoice.light => (Icons.light_mode_rounded, 'Light'),
        AppThemeChoice.dark => (Icons.dark_mode_rounded, 'Dark'),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = _config;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? context.colors.primarySoft : context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? context.colors.primary : context.colors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? context.colors.primary : context.colors.textMuted),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.body(
                size: 12,
                weight: FontWeight.w600,
                color: selected ? context.colors.primary : context.colors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
