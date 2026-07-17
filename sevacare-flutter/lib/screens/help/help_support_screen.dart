import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/faq_bot_sheet.dart';
import '../../widgets/widgets.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen> {
  final _nameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _submitted = false;
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() { _sending = false; _submitted = true; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final hospital = ref.watch(hospitalProvider);
    final isPlatformAdmin = auth.role == UserRole.platformAdmin;
    final isPharmacy = auth.isPharmacyOnly;
    final isAuthenticated = auth.isAuthenticated;
    final hospitalName = (isAuthenticated && !isPlatformAdmin && hospital.hospitalName.isNotEmpty)
        ? hospital.hospitalName
        : 'SevaCare';
    final entityLabel = isPharmacy ? 'Medical Store' : 'Hospital';

    return AppShell(
      hospitalName: isPlatformAdmin ? 'SevaCare' : hospitalName,
      role: auth.role,
      showBackButton: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          PageHeader(
            title: 'Help & Support',
            subtitle: isPlatformAdmin
                ? 'SevaCare platform support'
                : '$hospitalName support',
          ),
          const SizedBox(height: 20),

          // Assistant chatbot — answers common predefined questions per role
          _AssistantCard(role: auth.role),
          const SizedBox(height: 20),

          // Context badge
          _ContextBanner(isPlatformAdmin: isPlatformAdmin, isPharmacy: isPharmacy, hospitalName: hospitalName),
          const SizedBox(height: 20),

          // Contact details
          if (isPlatformAdmin) ...[
            _ContactCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: 'support@sevacare.in',
              color: context.colors.primary,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.phone_outlined,
              label: 'Toll-Free',
              value: '1800-SEVA-CARE',
              color: context.colors.mint,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.access_time_rounded,
              label: 'Support Hours',
              value: 'Mon – Sat, 9 AM – 6 PM IST',
              color: context.colors.peach,
            ),
          ] else ...[
            _ContactCard(
              icon: isPharmacy ? Icons.storefront_rounded : Icons.local_hospital_rounded,
              label: entityLabel,
              value: hospitalName,
              color: context.colors.primary,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: 'support@${hospitalName.toLowerCase().replaceAll(' ', '')}.in',
              color: context.colors.mint,
            ),
            const SizedBox(height: 10),
            _ContactCard(
              icon: Icons.access_time_rounded,
              label: 'Response Time',
              value: 'Within 24 hours on working days',
              color: context.colors.peach,
            ),
          ],
          const SizedBox(height: 24),

          // Message form
          if (_submitted)
            _SuccessBanner(isPlatformAdmin: isPlatformAdmin)
          else ...[
            Text('Send a Message', style: AppTextStyles.sectionTitle(context.colors.text)),
            const SizedBox(height: 4),
            Text(
              isPlatformAdmin
                  ? 'Describe your issue or question and our team will get back to you.'
                  : 'Send a message to the $hospitalName support team.',
              style: AppTextStyles.bodyText(context.colors.textMuted),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppFormField(
                    label: 'Your Name',
                    controller: _nameCtrl,
                    placeholder: 'Enter your full name',
                    required: true,
                  ),
                  AppFormField(
                    label: 'Message',
                    controller: _messageCtrl,
                    placeholder: 'Describe your issue or question in detail…',
                    required: true,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 4),
                  PrimaryButton(
                    label: 'Send Message',
                    icon: Icons.send_rounded,
                    isLoading: _sending,
                    fullWidth: true,
                    onPressed: _sending ? null : _submit,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),

          // The agreement this hospital works under — readable at any time, not only
          // at onboarding.
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Icon(Icons.verified_user_outlined,
                  color: context.colors.primary),
              title: Text('Terms of Service',
                  style: AppTextStyles.cardTitle(context.colors.text)),
              subtitle: Text('What SevaCare does with your data — and what it is not answerable for',
                  style: AppTextStyles.label(context.colors.textMuted)),
              trailing: Icon(Icons.chevron_right, color: context.colors.textMuted),
              onTap: () => context.push('/terms'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Assistant Card ─────────────────────────────────────────────────────────────

class _AssistantCard extends StatelessWidget {
  final UserRole? role;
  const _AssistantCard({required this.role});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showFaqBot(context, role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: context.colors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.colors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask the SevaCare Assistant',
                      style: AppTextStyles.cardTitle(context.colors.text)),
                  const SizedBox(height: 2),
                  Text('Quick answers to common questions',
                      style: AppTextStyles.label(context.colors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Context Banner ─────────────────────────────────────────────────────────────

class _ContextBanner extends StatelessWidget {
  final bool isPlatformAdmin;
  final bool isPharmacy;
  final String hospitalName;
  const _ContextBanner({required this.isPlatformAdmin, this.isPharmacy = false, required this.hospitalName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPlatformAdmin
              ? [const Color(0xFF5148CC), const Color(0xFF7C6FE0)]
              : [const Color(0xFF059669), const Color(0xFF10B981)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPlatformAdmin
                  ? Icons.support_agent_rounded
                  : (isPharmacy ? Icons.storefront_rounded : Icons.local_hospital_rounded),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlatformAdmin ? 'SevaCare Support' : '$hospitalName Support',
                  style: AppTextStyles.cardTitle(Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  isPlatformAdmin
                      ? 'Platform-level issues, onboarding, and billing'
                      : (isPharmacy
                          ? 'Billing, stock and counter queries'
                          : 'Hospital services, appointments, and clinical queries'),
                  style: AppTextStyles.label(Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact Card ───────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ContactCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label(context.colors.textMuted)),
              const SizedBox(height: 1),
              Text(value, style: AppTextStyles.cardTitle(context.colors.text)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Success Banner ─────────────────────────────────────────────────────────────

class _SuccessBanner extends StatelessWidget {
  final bool isPlatformAdmin;
  const _SuccessBanner({required this.isPlatformAdmin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.mintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: context.colors.mint.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.colors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 12),
          Text('Message Sent!', style: AppTextStyles.sectionTitle(context.colors.mintForeground)),
          const SizedBox(height: 6),
          Text(
            isPlatformAdmin
                ? 'Our SevaCare team will respond within 1 business day.'
                : 'The hospital support team will respond within 24 hours.',
            style: AppTextStyles.bodyText(context.colors.mintForeground),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
