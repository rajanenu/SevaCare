import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_state.dart';
import '../../widgets/faq_bot_sheet.dart';
import '../../widgets/widgets.dart';

/// The medical store's own help page — support contacts for the counter and
/// the platform, in the store's language. Deliberately separate from the
/// hospital HelpSupportScreen: nothing here mentions appointments or wards,
/// and its back button always returns to the counter.
class PharmacyHelpScreen extends ConsumerWidget {
  const PharmacyHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final shopName = auth.capabilities?.tenantName ?? 'Your Store';

    return AppShell(
      hospitalName: shopName,
      role: auth.role,
      showBackButton: true,
      helpRoute: '/pharmacy/help',
      homeRoute: '/pharmacy',
      onBack: () => context.canPop() ? context.pop() : context.go('/pharmacy'),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(title: 'Help & Support', subtitle: '$shopName support'),
        const SizedBox(height: 20),

        // Assistant chatbot for the counter's common questions.
        GestureDetector(
          onTap: () => showFaqBot(context, auth.role),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SevaCareColors.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius),
              border: Border.all(color: SevaCareColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: SevaCareColors.heroGradient,
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ask the SevaCare Assistant', style: AppTextStyles.cardTitle(SevaCareColors.text)),
                  const SizedBox(height: 2),
                  Text('Quick answers to common counter questions',
                      style: AppTextStyles.label(SevaCareColors.textMuted)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: SevaCareColors.textMuted),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Store-context banner.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF10B981)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$shopName Support', style: AppTextStyles.cardTitle(Colors.white)),
                const SizedBox(height: 3),
                Text('Billing, stock, refills and counter queries',
                    style: AppTextStyles.label(Colors.white.withValues(alpha: 0.85))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        _contact(Icons.email_outlined, 'SevaCare Support Email', 'support@sevacare.in', SevaCareColors.primary),
        const SizedBox(height: 10),
        _contact(Icons.phone_outlined, 'Toll-Free', '1800-SEVA-CARE', SevaCareColors.mint),
        const SizedBox(height: 10),
        _contact(Icons.access_time_rounded, 'Support Hours', 'Mon – Sat, 9 AM – 6 PM IST', SevaCareColors.peach),
        const SizedBox(height: 20),

        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Common questions', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
            const SizedBox(height: 6),
            _faq('How do I refill stock?',
                'Stock tab → tick the low or expiring items → Send Order → send it to your supplier by WhatsApp or email.'),
            _faq('A customer wants to pay later?',
                'Complete the sale with payment mode CREDIT and their mobile number — it lands in the Khata on the Dashboard, where you receive the payment later.'),
            _faq('GST rate changed for a medicine?',
                'Search it on the Sell tab and tap the pencil icon, or tap the item in the Stock tab alerts — update the GST % there.'),
            _faq('Made a wrong bill?',
                'Open Invoices on the Sell tab: refund lines the customer returned, or void the whole bill — stock goes back automatically.'),
          ]),
        ),
        const SizedBox(height: 20),

        // The agreement this store works under — readable at any time, not only at
        // onboarding.
        AppCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: SevaCareColors.primary),
            title: Text('Terms of Service', style: AppTextStyles.cardTitle(SevaCareColors.text)),
            subtitle: Text('What SevaCare does with your data — and what it is not answerable for',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
            trailing: const Icon(Icons.chevron_right, color: SevaCareColors.textMuted),
            onTap: () => context.push('/terms'),
          ),
        ),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _contact(IconData icon, String label, String value, Color color) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 1),
            Text(value, style: AppTextStyles.cardTitle(SevaCareColors.text)),
          ]),
        ]),
      );

  Widget _faq(String q, String a) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(q, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          const SizedBox(height: 2),
          Text(a, style: const TextStyle(fontSize: 12.5, color: SevaCareColors.textMuted)),
        ]),
      );
}
