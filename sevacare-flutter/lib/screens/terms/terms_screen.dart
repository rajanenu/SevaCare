import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

/// What SevaCare is, what it does with a customer's data, and what it is not
/// answerable for. Readable by anyone at any time — a hospital deciding whether to
/// join, and a store that signed up a year ago and wants to check what it agreed to.
///
/// The words come from the server (`/public/terms`), not from this file, so a revised
/// version reaches an installed APK without a release, and the copy a customer reads
/// is always the copy they accepted.
class TermsScreen extends ConsumerStatefulWidget {
  const TermsScreen({super.key});

  @override
  ConsumerState<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends ConsumerState<TermsScreen> {
  TermsDocument? _doc;
  TermsAcceptance? _acceptance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(repositoryProvider);
    final auth = ref.read(authProvider);
    try {
      final doc = await repo.getTerms();
      TermsAcceptance? acceptance;
      if (auth.token != null && auth.tenantPublicId != null) {
        try {
          acceptance = await repo.getTermsAcceptance(auth.tenantPublicId!, auth.token!);
        } catch (_) {
          // A patient or doctor has no acceptance of their own to show — the
          // document still reads perfectly well without it.
        }
      }
      if (mounted) {
        setState(() {
          _doc = doc;
          _acceptance = acceptance;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load the terms. Check your connection and try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final doc = _doc;

    return AppShell(
      hospitalName: auth.capabilities?.tenantName ?? 'SevaCare',
      role: auth.role,
      showBackButton: true,
      onBack: () => context.canPop() ? context.pop() : context.go('/'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(
            title: 'Terms of Service',
            subtitle: 'What we do with your data, and what we are not answerable for',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null || doc == null)
            AppCard(
              child: Column(children: [
                Text(_error ?? 'Terms unavailable.',
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Retry', onPressed: _load),
              ]),
            )
          else ...[
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.verified_user_outlined,
                      size: 18, color: SevaCareColors.primary),
                  const SizedBox(width: 8),
                  Text('Version ${doc.version} · in force from ${doc.effectiveDate}',
                      style: AppTextStyles.label(SevaCareColors.textMuted)),
                ]),
                const SizedBox(height: 10),
                Text(doc.summary, style: AppTextStyles.bodyText(SevaCareColors.text)),
              ]),
            ),
            if (_acceptance != null) ...[
              const SizedBox(height: 12),
              _acceptanceCard(_acceptance!),
            ],
            const SizedBox(height: 16),
            for (final section in doc.sections) ...[
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(section.heading,
                      style: AppTextStyles.sectionTitle(SevaCareColors.text)),
                  const SizedBox(height: 8),
                  for (final p in section.paragraphs) ...[
                    Text(p, style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                    if (p != section.paragraphs.last) const SizedBox(height: 8),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            Text(
              'Questions about these terms? Write to support@sevacare.in.',
              style: AppTextStyles.label(SevaCareColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _acceptanceCard(TermsAcceptance a) {
    final accepted = a.upToDate;
    final color = accepted ? SevaCareColors.mint : SevaCareColors.warning;
    final when = a.acceptedAt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(accepted ? Icons.check_circle_outline : Icons.pending_outlined,
            size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            accepted
                ? 'Accepted by ${a.acceptedBy ?? 'your team'}'
                    '${when != null ? ' on ${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}' : ''}'
                    ' · version ${a.acceptedVersion}'
                : 'Not yet accepted for this account. You will be asked to accept when you next open your dashboard.',
            style: AppTextStyles.bodyText(SevaCareColors.text),
          ),
        ),
      ]),
    );
  }
}

/// Ask the owner of a hospital or a store to accept the terms, once, if they have
/// not — and do not let the app carry on until they answer. Called from the two
/// screens a tenant's own admin lands on after signing in.
///
/// Only the tenant's own people are asked: a doctor or a patient never signed the
/// agreement and cannot accept it on the business's behalf.
Future<void> maybeAskForTerms(BuildContext context, WidgetRef ref) async {
  final auth = ref.read(authProvider);
  final caps = auth.capabilities;
  if (caps == null || caps.termsAccepted) return;

  if (auth.role != UserRole.admin && auth.role != UserRole.staff) return;
  if (auth.token == null || auth.tenantPublicId == null) return;

  TermsDocument doc;
  try {
    doc = await ref.read(repositoryProvider).getTerms();
  } catch (_) {
    return; // Unreachable terms must not lock anyone out of their own counter.
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TermsGateDialog(doc: doc),
  );
}

class _TermsGateDialog extends ConsumerStatefulWidget {
  final TermsDocument doc;
  const _TermsGateDialog({required this.doc});

  @override
  ConsumerState<_TermsGateDialog> createState() => _TermsGateDialogState();
}

class _TermsGateDialogState extends ConsumerState<_TermsGateDialog> {
  // Ticked by default — the intent is to confirm what was already agreed at
  // onboarding, not to spring a new condition. Untick it and Accept is refused.
  bool _agreed = true;
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final auth = ref.read(authProvider);
    try {
      final accepted = await ref.read(repositoryProvider).acceptTerms(
            auth.tenantPublicId!,
            auth.token!,
            widget.doc.version,
            auth.subjectName.isNotEmpty ? auth.subjectName : 'Account owner',
          );
      final caps = auth.capabilities;
      if (caps != null) {
        ref.read(authProvider.notifier).setCapabilities(Capabilities(
              tenantPublicId: caps.tenantPublicId,
              tenantName: caps.tenantName,
              modules: caps.modules,
              pharmacyProfileKey: caps.pharmacyProfileKey,
              pharmacyFeatures: caps.pharmacyFeatures,
              termsVersion: accepted.currentVersion,
              termsAccepted: accepted.upToDate,
            ));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not record your acceptance. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radius)),
      title: Row(children: [
        const Icon(Icons.verified_user_outlined, color: SevaCareColors.primary, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text('SevaCare Terms of Service',
              style: AppTextStyles.sectionTitle(SevaCareColors.text)),
        ),
      ]),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Version ${doc.version} · ${doc.effectiveDate}',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
            const SizedBox(height: 10),
            Text(doc.summary, style: AppTextStyles.bodyText(SevaCareColors.text)),
            const SizedBox(height: 12),
            // The three points that matter most, in the customer's own interest.
            for (final section in doc.sections.take(3)) ...[
              Text(section.heading, style: AppTextStyles.cardTitle(SevaCareColors.text)),
              const SizedBox(height: 4),
              Text(section.paragraphs.first,
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
              const SizedBox(height: 10),
            ],
            TextButton.icon(
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Read the full terms'),
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/terms');
              },
            ),
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _agreed,
              onChanged: _saving ? null : (v) => setState(() => _agreed = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text(
                'I have read and accept these terms on behalf of my business.',
                style: AppTextStyles.bodyText(SevaCareColors.text),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: AppTextStyles.label(SevaCareColors.danger)),
            ],
          ]),
        ),
      ),
      actions: [
        PrimaryButton(
          label: 'Accept & Continue',
          isLoading: _saving,
          onPressed: (!_agreed || _saving) ? null : _accept,
        ),
      ],
    );
  }
}
