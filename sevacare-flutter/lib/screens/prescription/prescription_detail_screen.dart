import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/prescription_pdf.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class PrescriptionDetailScreen extends ConsumerStatefulWidget {
  final String prescriptionId;

  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  ConsumerState<PrescriptionDetailScreen> createState() =>
      _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState
    extends ConsumerState<PrescriptionDetailScreen> {
  PrescriptionDetailView? _detail;
  bool _loading = true;
  bool _downloading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final data = await repo.getPrescriptionDetail(
        auth.tenantPublicId ?? '',
        widget.prescriptionId,
        auth.token ?? '',
      );
      if (mounted) setState(() => _detail = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _downloadPdf() async {
    final rx = _detail;
    if (rx == null) return;
    final hospital = ref.read(hospitalProvider);
    setState(() => _downloading = true);
    try {
      await PrescriptionPdfService.download(
        hospitalName: hospital.hospitalName.isNotEmpty ? hospital.hospitalName : 'SevaCare',
        rx: rx,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: context.colors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _rxLabel(String id) {
    final clean = id.replaceAll('-', '').toUpperCase();
    final suffix = clean.length > 8 ? clean.substring(clean.length - 8) : clean;
    return 'RX-$suffix';
  }

  @override
  Widget build(BuildContext context) {
    final hospital = ref.watch(hospitalProvider);
    final rx = _detail;

    return AppShell(
      hospitalName: hospital.hospitalName,
      role: UserRole.patient,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Back button
          BackBtn(onPressed: () => context.canPop() ? context.pop() : context.go('/patient/prescriptions')),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: ShimmerList(count: 3, cardHeight: 120),
            )
          else if (_error != null)
            SizedBox(
              height: 400,
              child: AppErrorState(message: _error!, onRetry: _load),
            )
          else if (rx == null)
            const SizedBox(
              height: 400,
              child: AppEmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Prescription not found',
              ),
            )
          else ...[
            // ── Page header
            PageHeader(
              title: _rxLabel(rx.prescriptionPublicId),
              subtitle: 'Issued by Dr. ${rx.doctorName}',
            ),
            const SizedBox(height: 8),

            // ── Header info card
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Issued On',
                    value: AppDateUtils.formatDisplay(rx.issuedOn),
                  ),
                  if (rx.validUntil != null && rx.validUntil!.isNotEmpty)
                    InfoRow(
                      label: 'Valid Until',
                      value: AppDateUtils.formatDisplay(rx.validUntil),
                    ),
                  InfoRow(label: 'Doctor', value: 'Dr. ${rx.doctorName}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('Status',
                          style: AppTextStyles.label(context.colors.textMuted)),
                      const SizedBox(width: 12),
                      StatusBadge(status: rx.status),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Medicines card
            Text('Medicines', style: AppTextStyles.sectionTitle(context.colors.text)),
            const SizedBox(height: 12),
            if (rx.medicines.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No medicines listed',
                    style: AppTextStyles.bodyText(context.colors.textMuted),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rx.medicines.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final med = rx.medicines[index];
                  return AccentCard(
                    variant: MetricVariant.mint,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Medicine name
                        Text(
                          med.name,
                          style: AppTextStyles.cardTitle(context.colors.text),
                        ),
                        const SizedBox(height: 8),
                        // Chips: strength, frequency, duration
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (med.strength.isNotEmpty)
                              _MedChip(label: med.strength, icon: Icons.science_outlined),
                            if (med.frequency.isNotEmpty)
                              _MedChip(label: med.frequency, icon: Icons.schedule_outlined),
                            if (med.duration.isNotEmpty)
                              _MedChip(label: med.duration, icon: Icons.hourglass_bottom_outlined),
                          ],
                        ),
                        // Instructions
                        if (med.instructions != null && med.instructions!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            med.instructions!,
                            style: AppTextStyles.bodyText(context.colors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 16),

            // ── Notes card (if any)
            if (rx.notes != null && rx.notes!.isNotEmpty) ...[
              Text('Notes', style: AppTextStyles.sectionTitle(context.colors.text)),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Text(
                  rx.notes!,
                  style: AppTextStyles.bodyText(context.colors.textMuted),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Download as PDF
            SecondaryButton(
              label: _downloading ? 'Generating PDF…' : 'Download Prescription (PDF)',
              icon: _downloading ? Icons.hourglass_empty : Icons.picture_as_pdf_outlined,
              fullWidth: true,
              onPressed: _downloading ? null : _downloadPdf,
            ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }
}

// ── Medicine detail chip ──────────────────────────────────────────────────────

class _MedChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MedChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.colors.mintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(
          color: context.colors.mint.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.colors.mintForeground),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.chipLabel(context.colors.mintForeground)),
        ],
      ),
    );
  }
}
