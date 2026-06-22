import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/models.dart';
import '../../providers/app_state.dart';
import '../../widgets/widgets.dart';

class ConsultationScreen extends ConsumerStatefulWidget {
  const ConsultationScreen({super.key});

  @override
  ConsumerState<ConsultationScreen> createState() => _ConsultationScreenState();
}

class _ConsultationScreenState extends ConsumerState<ConsultationScreen> {
  // Medicine list being built
  final List<MedicineView> _medicines = [];

  // Add-medicine form controllers
  final _medNameCtrl = TextEditingController();
  final _medStrengthCtrl = TextEditingController();
  final _medFreqCtrl = TextEditingController();
  final _medDurationCtrl = TextEditingController();
  final _medInstructionsCtrl = TextEditingController();

  // Notes controller
  final _notesCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _medNameCtrl.dispose();
    _medStrengthCtrl.dispose();
    _medFreqCtrl.dispose();
    _medDurationCtrl.dispose();
    _medInstructionsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _addMedicine() {
    final name = _medNameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicine name is required.'),
          backgroundColor: SevaCareColors.danger,
        ),
      );
      return;
    }
    setState(() {
      _medicines.add(MedicineView(
        name: name,
        strength: _medStrengthCtrl.text.trim(),
        frequency: _medFreqCtrl.text.trim(),
        duration: _medDurationCtrl.text.trim(),
        instructions: _medInstructionsCtrl.text.trim().isNotEmpty
            ? _medInstructionsCtrl.text.trim()
            : null,
      ));
      _medNameCtrl.clear();
      _medStrengthCtrl.clear();
      _medFreqCtrl.clear();
      _medDurationCtrl.clear();
      _medInstructionsCtrl.clear();
    });
  }

  void _removeMedicine(int index) {
    setState(() => _medicines.removeAt(index));
  }

  Future<void> _issuePrescription() async {
    if (_medicines.isEmpty) {
      setState(() => _error = 'Add at least one medicine before issuing a prescription.');
      return;
    }

    final patientId = ref.read(doctorSelectedPatientIdProvider);
    final appointmentId = ref.read(doctorSelectedAppointmentIdProvider);

    if (patientId == null || patientId.isEmpty) {
      setState(() => _error = 'No patient selected. Please go back and select a patient.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final doctorId = auth.subjectPublicId ?? '';

      final result = await repo.uploadPrescription(
        hospital.tenantPublicId,
        doctorId,
        auth.token ?? '',
        PrescriptionUploadRequest(
          patientPublicId: patientId,
          appointmentPublicId: appointmentId,
          medicines: List.unmodifiable(_medicines),
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        ),
      );

      if (mounted) {
        setState(() => _submitting = false);
        final rxId = result['prescriptionPublicId'] as String? ??
            result['id'] as String? ??
            'RX-issued';
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            backgroundColor: SevaCareColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: SevaCareColors.successSurface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: SevaCareColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                Text('Prescription Issued', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The prescription has been successfully issued.',
                  style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SevaCareColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 16, color: SevaCareColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rxId,
                          style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: SevaCareColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/doctor');
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = ref.watch(doctorSelectedPatientIdProvider);
    final hospital = ref.watch(hospitalProvider);
    final auth = ref.watch(authProvider);

    return AppShell(
      hospitalName: hospital.hospitalName.isNotEmpty ? hospital.hospitalName : 'SevaCare',
      role: auth.role ?? UserRole.doctor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          BackBtn(onPressed: () => context.go('/doctor')),
          const SizedBox(height: 12),

          PageHeader(
            title: 'Consultation',
            subtitle: patientId != null && patientId.isNotEmpty
                ? 'Patient: $patientId'
                : 'No patient selected',
          ),
          const SizedBox(height: 16),

          // ── Write Prescription section ─────────────────────────────────────
          Text('Write Prescription', style: AppTextStyles.sectionTitle(SevaCareColors.text)),
          const SizedBox(height: 12),

          // Current medicines list
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 18, color: SevaCareColors.primary),
                    const SizedBox(width: 8),
                    Text('Prescription', style: AppTextStyles.cardTitle(SevaCareColors.text)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: SevaCareColors.primarySoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_medicines.length} item(s)',
                        style: AppTextStyles.label(SevaCareColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_medicines.isEmpty)
                  Text(
                    'No medicines added yet. Use the form below to add medicines.',
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < _medicines.length; i++) ...[
                        _MedicineRow(
                          medicine: _medicines[i],
                          index: i,
                          onDelete: () => _removeMedicine(i),
                        ),
                        if (i < _medicines.length - 1)
                          const SectionDivider(),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Add medicine form ──────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_circle_outline, size: 18, color: SevaCareColors.mint),
                    const SizedBox(width: 8),
                    Text('Add Medicine', style: AppTextStyles.cardTitle(SevaCareColors.text)),
                  ],
                ),
                const SizedBox(height: 12),
                AppFormField(
                  label: 'Medicine Name',
                  controller: _medNameCtrl,
                  required: true,
                  placeholder: 'e.g. Paracetamol',
                ),
                AppFormField(
                  label: 'Strength',
                  controller: _medStrengthCtrl,
                  placeholder: 'e.g. 500mg',
                ),
                AppFormField(
                  label: 'Frequency',
                  controller: _medFreqCtrl,
                  placeholder: 'e.g. Twice daily',
                ),
                AppFormField(
                  label: 'Duration',
                  controller: _medDurationCtrl,
                  placeholder: 'e.g. 5 days',
                ),
                AppFormField(
                  label: 'Instructions',
                  controller: _medInstructionsCtrl,
                  placeholder: 'e.g. After meals',
                  maxLines: 2,
                ),
                PrimaryButton(
                  label: 'Add to List',
                  icon: Icons.add,
                  onPressed: _addMedicine,
                  fullWidth: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Notes ──────────────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notes_outlined, size: 18, color: SevaCareColors.textMuted),
                    const SizedBox(width: 8),
                    Text('Doctor Notes', style: AppTextStyles.cardTitle(SevaCareColors.text)),
                    Text(' (optional)', style: AppTextStyles.label(SevaCareColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  style: AppTextStyles.inputText(SevaCareColors.text),
                  decoration: InputDecoration(
                    hintText: 'Enter any clinical notes, diagnosis, or instructions...',
                    hintStyle: AppTextStyles.inputHint(
                      SevaCareColors.textMuted.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: SevaCareColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SevaCareColors.border, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SevaCareColors.border, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: SevaCareColors.primary, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Error banner ───────────────────────────────────────────────────
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SevaCareColors.errorSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SevaCareColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 18, color: SevaCareColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!, style: AppTextStyles.bodyText(SevaCareColors.danger)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // ── Issue Prescription button ──────────────────────────────────────
          PrimaryButton(
            label: 'Issue Prescription',
            icon: Icons.send_outlined,
            isLoading: _submitting,
            onPressed: _submitting ? null : _issuePrescription,
            fullWidth: true,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Medicine row inside the prescription card ─────────────────────────────────

class _MedicineRow extends StatelessWidget {
  final MedicineView medicine;
  final int index;
  final VoidCallback onDelete;

  const _MedicineRow({
    required this.medicine,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: SevaCareColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: AppTextStyles.label(SevaCareColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: AppTextStyles.body(
                    size: 14,
                    weight: FontWeight.w600,
                    color: SevaCareColors.text,
                  ),
                ),
                if (medicine.strength.isNotEmpty)
                  Text(
                    medicine.strength,
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                  ),
                if (medicine.frequency.isNotEmpty || medicine.duration.isNotEmpty)
                  Text(
                    [
                      if (medicine.frequency.isNotEmpty) medicine.frequency,
                      if (medicine.duration.isNotEmpty) medicine.duration,
                    ].join(' · '),
                    style: AppTextStyles.bodyText(SevaCareColors.textMuted),
                  ),
                if (medicine.instructions != null && medicine.instructions!.isNotEmpty)
                  Text(
                    medicine.instructions!,
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: SevaCareColors.errorSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: SevaCareColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
