import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/ai/clinical_assist.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/error_utils.dart';
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

  // Vitals controllers
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _pulseCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _spo2Ctrl = TextEditingController();
  final _sugarCtrl = TextEditingController();
  bool _vitalsExpanded = false;

  // Medicine autocomplete
  List<String> _medicineSuggestions = [];

  bool _submitting = false;
  String? _error;

  // Patient history
  List<PrescriptionDetailView> _prevPrescriptions = [];
  bool _historyLoading = false;
  bool _historyExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPatientHistory());
    _medNameCtrl.addListener(_onMedicineNameChanged);
  }

  @override
  void dispose() {
    _medNameCtrl.removeListener(_onMedicineNameChanged);
    _medNameCtrl.dispose();
    _medStrengthCtrl.dispose();
    _medFreqCtrl.dispose();
    _medDurationCtrl.dispose();
    _medInstructionsCtrl.dispose();
    _notesCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _tempCtrl.dispose();
    _pulseCtrl.dispose();
    _weightCtrl.dispose();
    _spo2Ctrl.dispose();
    _sugarCtrl.dispose();
    super.dispose();
  }

  void _onMedicineNameChanged() {
    final query = _medNameCtrl.text.trim().toLowerCase();
    if (query.length < 2) {
      if (_medicineSuggestions.isNotEmpty) setState(() => _medicineSuggestions = []);
      return;
    }
    final matches = _kCommonMedicines
        .where((m) => m.toLowerCase().contains(query))
        .take(6)
        .toList();
    setState(() => _medicineSuggestions = matches);
  }

  String? _buildVitalsString() {
    final sys = _systolicCtrl.text.trim();
    final dia = _diastolicCtrl.text.trim();
    final temp = _tempCtrl.text.trim();
    final pulse = _pulseCtrl.text.trim();
    final weight = _weightCtrl.text.trim();
    final spo2 = _spo2Ctrl.text.trim();
    final sugar = _sugarCtrl.text.trim();
    final parts = <String>[
      if (sys.isNotEmpty && dia.isNotEmpty) 'BP: $sys/$dia mmHg',
      if (temp.isNotEmpty) 'Temp: $temp°C',
      if (pulse.isNotEmpty) 'Pulse: $pulse bpm',
      if (weight.isNotEmpty) 'Wt: $weight kg',
      if (spo2.isNotEmpty) 'SpO₂: $spo2%',
      if (sugar.isNotEmpty) 'Sugar: $sugar mg/dL',
    ];
    return parts.isEmpty ? null : '[Vitals] ${parts.join(' | ')}';
  }

  Future<void> _loadPatientHistory() async {
    final patientId = ref.read(doctorSelectedPatientIdProvider);
    if (patientId == null || patientId.isEmpty) return;
    setState(() => _historyLoading = true);
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      final result = await repo.getPatientPrescriptions(
        hospital.tenantPublicId, patientId, auth.token ?? '');
      if (mounted) {
        setState(() {
          _prevPrescriptions = result.prescriptions.take(3).toList();
          _historyLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoading = false);
    }
  }

  void _showPrevPrescriptionDialog(PrescriptionDetailView rx) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SevaCareColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(color: SevaCareColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.medication_outlined, size: 16, color: SevaCareColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rx.prescriptionPublicId, style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: SevaCareColors.text)),
                  Text('Issued: ${rx.issuedOn}', style: AppTextStyles.label(SevaCareColors.textMuted)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => Navigator.of(ctx).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 400),
          child: rx.medicines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No medicines recorded for this prescription.',
                      style: AppTextStyles.bodyText(SevaCareColors.textMuted)),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      for (int i = 0; i < rx.medicines.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: SevaCareColors.border),
                        _MedicineDetailTile(medicine: rx.medicines[i], index: i),
                      ],
                    ],
                  ),
                ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: 'Close',
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeConsultation(String appointmentId) async {
    try {
      final auth = ref.read(authProvider);
      final hospital = ref.read(hospitalProvider);
      final repo = ref.read(repositoryProvider);
      await repo.completeConsultation(
        hospital.tenantPublicId,
        auth.subjectPublicId ?? '',
        appointmentId,
        auth.token ?? '',
      );
    } catch (_) {
      // Completion is best-effort; prescription already saved
    }
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

      final doctorName = auth.subjectName.isNotEmpty ? auth.subjectName : 'Doctor';
      final vitalsStr = _buildVitalsString();
      final userNotes = _notesCtrl.text.trim();
      final combinedNotes = [
        if (vitalsStr != null) vitalsStr,
        if (userNotes.isNotEmpty) userNotes,
      ].join('\n');
      final result = await repo.uploadPrescription(
        hospital.tenantPublicId,
        doctorId,
        auth.token ?? '',
        PrescriptionUploadRequest(
          patientPublicId: patientId,
          doctorPublicId: doctorId,
          doctorName: doctorName,
          appointmentPublicId: appointmentId,
          medicines: List.unmodifiable(_medicines),
          notes: combinedNotes.isNotEmpty ? combinedNotes : null,
        ),
      );

      if (mounted) {
        setState(() => _submitting = false);
        final rxId = result['prescriptionPublicId'] as String? ??
            result['id'] as String? ??
            'RX-issued';
        final apptId = appointmentId;
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
                Flexible(child: Text('Prescription Issued', style: AppTextStyles.sectionTitle(SevaCareColors.text))),
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
                          style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: SevaCareColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Complete consultation prompt
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SevaCareColors.mintSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: SevaCareColors.mint.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: SevaCareColors.mint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mark this consultation as complete?',
                          style: AppTextStyles.bodyText(SevaCareColors.mintForeground),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: SevaCareColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.event_repeat, size: 16, color: SevaCareColors.peach),
                    const SizedBox(width: 8),
                    Text(
                      'Schedule Follow-up?',
                      style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: SevaCareColors.peach),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [3, 7, 14, 30].map((days) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Follow-up in $days days noted in prescription.'),
                          backgroundColor: SevaCareColors.peach,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: const Duration(seconds: 3),
                        ));
                        context.go('/doctor');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF4EE),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: SevaCareColors.peach.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          '$days days',
                          style: AppTextStyles.label(SevaCareColors.peach),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              SecondaryButton(
                label: 'Close',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go('/doctor');
                },
              ),
              PrimaryButton(
                label: 'Complete & Close',
                icon: Icons.check_circle_outline,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (apptId != null && apptId.isNotEmpty) {
                    await _completeConsultation(apptId);
                  }
                  if (mounted) context.go('/doctor');
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
          _error = extractErrorMessage(e, fallback: 'Failed to issue prescription. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = ref.watch(doctorSelectedPatientIdProvider);
    final hospital = ref.watch(hospitalProvider);
    final auth = ref.watch(authProvider);
    final facet = ref.watch(doctorSelectedFacetProvider);

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

          // ── Intake summary + AI assist ─────────────────────────────────────
          if (facet != null &&
              ((facet.symptoms?.isNotEmpty ?? false) ||
                  (facet.vitals?.isNotEmpty ?? false))) ...[
            _IntakeAssistCard(facet: facet),
            const SizedBox(height: 12),
          ],

          // ── Patient-uploaded prescriptions (attached at booking) ─────────────
          if (facet != null && facet.attachments.isNotEmpty) ...[
            _UploadedPrescriptionsCard(attachments: facet.attachments),
            const SizedBox(height: 12),
          ],

          // ── Patient History Panel ──────────────────────────────────────────
          GestureDetector(
            onTap: () => setState(() => _historyExpanded = !_historyExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _historyExpanded ? SevaCareColors.primarySoft : SevaCareColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SevaCareColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_outlined, size: 18, color: SevaCareColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _historyLoading
                          ? 'Loading patient history…'
                          : _prevPrescriptions.isEmpty
                              ? 'No previous prescriptions on record'
                              : 'Previous Prescriptions (${_prevPrescriptions.length})',
                      style: AppTextStyles.body(size: 13, weight: FontWeight.w600, color: SevaCareColors.primary),
                    ),
                  ),
                  Icon(
                    _historyExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: SevaCareColors.primary,
                  ),
                ],
              ),
            ),
          ),
          if (_historyExpanded && _prevPrescriptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < _prevPrescriptions.length; i++) ...[
                    if (i > 0) const SectionDivider(),
                    _PrevPrescriptionRow(
                      prescription: _prevPrescriptions[i],
                      onTap: () => _showPrevPrescriptionDialog(_prevPrescriptions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // ── Vitals Recording ──────────────────────────────────────────────
          _VitalsSection(
            expanded: _vitalsExpanded,
            onToggle: () => setState(() => _vitalsExpanded = !_vitalsExpanded),
            systolicCtrl: _systolicCtrl,
            diastolicCtrl: _diastolicCtrl,
            tempCtrl: _tempCtrl,
            pulseCtrl: _pulseCtrl,
            weightCtrl: _weightCtrl,
            spo2Ctrl: _spo2Ctrl,
            sugarCtrl: _sugarCtrl,
          ),
          const SizedBox(height: 12),

          // ── Quick Prescription Templates ──────────────────────────────────
          _QuickTemplatesBar(
            onApply: (medicines, notes) {
              setState(() {
                _medicines.addAll(medicines);
                if (notes.isNotEmpty && _notesCtrl.text.isEmpty) {
                  _notesCtrl.text = notes;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Template applied — review and adjust medicines.'),
                  backgroundColor: SevaCareColors.mint,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
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
                if (_medicineSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: SevaCareColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: SevaCareColors.primary.withValues(alpha: 0.4)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
                    ),
                    child: Column(
                      children: _medicineSuggestions.asMap().entries.map((e) {
                        final isLast = e.key == _medicineSuggestions.length - 1;
                        return Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                _medNameCtrl.text = e.value;
                                setState(() => _medicineSuggestions = []);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.medication_outlined, size: 14, color: SevaCareColors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(e.value, style: AppTextStyles.bodyText(SevaCareColors.text))),
                                    const Icon(Icons.north_west, size: 12, color: SevaCareColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 38, color: SevaCareColors.border),
                          ],
                        );
                      }).toList(),
                    ),
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

// ── Previous prescription summary row ────────────────────────────────────────

// ── Intake summary + AI assist card ──────────────────────────────────────────

class _IntakeAssistCard extends StatelessWidget {
  final DoctorQueueFacetView facet;
  const _IntakeAssistCard({required this.facet});

  @override
  Widget build(BuildContext context) {
    final insights = ClinicalAssist.analyze(
      vitals: facet.vitals,
      symptoms: facet.symptoms,
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 16, color: SevaCareColors.primary),
              const SizedBox(width: 8),
              Text('Intake & AI Assist', style: AppTextStyles.cardTitle(SevaCareColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          if (facet.symptoms?.isNotEmpty ?? false) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.sick_outlined, size: 14, color: SevaCareColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facet.symptoms!,
                    style: AppTextStyles.bodyText(SevaCareColors.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (facet.vitals?.isNotEmpty ?? false) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SevaCareColors.skySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.monitor_heart_outlined,
                      size: 14, color: SevaCareColors.skyForeground),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Vitals at intake (by IP-Staff)',
                            style: AppTextStyles.label(SevaCareColors.skyForeground)),
                        const SizedBox(height: 2),
                        Text(
                          facet.vitals!,
                          style: AppTextStyles.body(
                            size: 13,
                            weight: FontWeight.w600,
                            color: SevaCareColors.skyForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...insights.map((insight) {
            final (color, icon) = switch (insight.severity) {
              InsightSeverity.alert => (SevaCareColors.danger, Icons.priority_high_rounded),
              InsightSeverity.watch => (SevaCareColors.warning, Icons.visibility_outlined),
              InsightSeverity.info => (SevaCareColors.textMuted, Icons.info_outline),
            };
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(insight.text, style: AppTextStyles.label(color)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          Text(
            'AI hints from intake data — clinical judgement prevails.',
            style: AppTextStyles.label(
              SevaCareColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Patient-uploaded prescriptions card ──────────────────────────────────────

class _UploadedPrescriptionsCard extends StatelessWidget {
  final List<AttachmentView> attachments;
  const _UploadedPrescriptionsCard({required this.attachments});

  void _openFullScreen(BuildContext context, AttachmentView attachment) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.memory(base64Decode(attachment.dataBase64)),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, size: 16, color: SevaCareColors.primary),
              const SizedBox(width: 8),
              Text('Patient-Uploaded Prescriptions (${attachments.length})',
                  style: AppTextStyles.cardTitle(SevaCareColors.text)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: attachments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final a = attachments[i];
                return GestureDetector(
                  onTap: () => _openFullScreen(context, a),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      base64Decode(a.dataBase64),
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a photo to view full size.',
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PrevPrescriptionRow extends StatelessWidget {
  final PrescriptionDetailView prescription;
  final VoidCallback? onTap;
  const _PrevPrescriptionRow({required this.prescription, this.onTap});

  @override
  Widget build(BuildContext context) {
    final meds = prescription.medicines;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: SevaCareColors.primarySoft, shape: BoxShape.circle),
              child: const Icon(Icons.medication_outlined, size: 14, color: SevaCareColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        prescription.prescriptionPublicId,
                        style: AppTextStyles.body(size: 12, weight: FontWeight.w600, color: SevaCareColors.primary),
                      ),
                      const Spacer(),
                      Text(
                        prescription.issuedOn,
                        style: AppTextStyles.label(SevaCareColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (meds.isEmpty)
                    Text('No medicines listed', style: AppTextStyles.label(SevaCareColors.textMuted))
                  else
                    Text(
                      meds.map((m) => m.name).join(', '),
                      style: AppTextStyles.label(SevaCareColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: SevaCareColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Medicine detail tile inside the history popup ─────────────────────────────

class _MedicineDetailTile extends StatelessWidget {
  final MedicineView medicine;
  final int index;
  const _MedicineDetailTile({required this.medicine, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: SevaCareColors.primarySoft, shape: BoxShape.circle),
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
                  medicine.name.isNotEmpty ? medicine.name : '(unnamed)',
                  style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: SevaCareColors.text),
                ),
                if (medicine.strength.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(medicine.strength, style: AppTextStyles.label(SevaCareColors.primary)),
                ],
                if (medicine.frequency.isNotEmpty || medicine.duration.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (medicine.frequency.isNotEmpty) medicine.frequency,
                      if (medicine.duration.isNotEmpty) medicine.duration,
                    ].join(' · '),
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
                if (medicine.instructions != null && medicine.instructions!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    medicine.instructions!,
                    style: AppTextStyles.label(SevaCareColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
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

// ── Quick Prescription Templates ──────────────────────────────────────────────
// Feature #2: One-tap condition templates that pre-fill medicines + notes.

typedef _TemplateApplyCallback = void Function(
    List<MedicineView> medicines, String notes);

class _QuickTemplatesBar extends StatefulWidget {
  final _TemplateApplyCallback onApply;
  const _QuickTemplatesBar({required this.onApply});

  @override
  State<_QuickTemplatesBar> createState() => _QuickTemplatesBarState();
}

class _QuickTemplatesBarState extends State<_QuickTemplatesBar> {
  bool _expanded = false;

  static const _templates = [
    _RxTemplate(
      label: 'Common Cold',
      icon: Icons.sick_outlined,
      color: Color(0xFF6366F1),
      notes: 'Rest, stay hydrated, avoid cold food/drinks.',
      medicines: [
        (name: 'Paracetamol', strength: '500mg', freq: 'TDS', dur: '5 days',   note: 'After food'),
        (name: 'Cetirizine',  strength: '10mg',  freq: 'OD',  dur: '5 days',   note: 'At night'),
        (name: 'Ambroxol',    strength: '30mg',  freq: 'BD',  dur: '5 days',   note: 'After food'),
      ],
    ),
    _RxTemplate(
      label: 'Hypertension',
      icon: Icons.favorite_border,
      color: Color(0xFFDB4E2D),
      notes: 'Low-salt diet. Monitor BP daily. Follow up in 2 weeks.',
      medicines: [
        (name: 'Amlodipine',  strength: '5mg',  freq: 'OD', dur: '30 days', note: 'Morning'),
        (name: 'Telmisartan', strength: '40mg', freq: 'OD', dur: '30 days', note: 'Morning'),
      ],
    ),
    _RxTemplate(
      label: 'Diabetes F/U',
      icon: Icons.water_drop_outlined,
      color: Color(0xFFF0A86B),
      notes: 'Check HbA1c in 3 months. Low-sugar diet. Walk 30 min daily.',
      medicines: [
        (name: 'Metformin',   strength: '500mg', freq: 'BD', dur: '30 days', note: 'After food'),
        (name: 'Glimepiride', strength: '1mg',   freq: 'OD', dur: '30 days', note: 'Before breakfast'),
      ],
    ),
    _RxTemplate(
      label: 'Gastritis',
      icon: Icons.medication_outlined,
      color: Color(0xFF52C499),
      notes: 'Avoid spicy food, alcohol, NSAIDs. Eat small frequent meals.',
      medicines: [
        (name: 'Pantoprazole', strength: '40mg', freq: 'OD',  dur: '14 days', note: '30 min before food'),
        (name: 'Domperidone',  strength: '10mg', freq: 'TDS', dur: '7 days',  note: 'Before meals'),
        (name: 'Sucralfate',   strength: '1g',   freq: 'TDS', dur: '7 days',  note: 'After meals'),
      ],
    ),
    _RxTemplate(
      label: 'Migraine',
      icon: Icons.psychology_outlined,
      color: Color(0xFF7C6FE0),
      notes: 'Avoid triggers. Rest in dark room during attack.',
      medicines: [
        (name: 'Sumatriptan', strength: '50mg',  freq: 'SOS', dur: 'As needed', note: 'At onset'),
        (name: 'Naproxen',    strength: '500mg', freq: 'BD',  dur: '3 days',    note: 'With food'),
        (name: 'Propranolol', strength: '20mg',  freq: 'BD',  dur: '30 days',   note: 'Prevention'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: SevaCareColors.peachSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SevaCareColors.peach.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: SevaCareColors.peach),
                const SizedBox(width: 8),
                Text(
                  'Quick Templates',
                  style: AppTextStyles.body(
                    size: 13, weight: FontWeight.w700,
                    color: SevaCareColors.peachForeground,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: SevaCareColors.peach.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${_templates.length} conditions',
                      style: AppTextStyles.label(SevaCareColors.peachForeground)),
                ),
                const Spacer(),
                Text(_expanded ? 'Hide' : 'Show',
                    style: AppTextStyles.label(SevaCareColors.peachForeground)),
                Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18, color: SevaCareColors.peachForeground),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _templates.map((t) => _TemplateChip(
              template: t,
              onTap: () {
                final medicines = t.medicines.map((m) => MedicineView(
                  name: m.name,
                  strength: m.strength,
                  frequency: m.freq,
                  duration: m.dur,
                  instructions: m.note,
                )).toList();
                widget.onApply(medicines, t.notes);
              },
            )).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a condition to add pre-filled medicines. Edit them below before issuing.',
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _RxTemplate {
  final String label;
  final IconData icon;
  final Color color;
  final String notes;
  final List<({String name, String strength, String freq, String dur, String note})> medicines;

  const _RxTemplate({
    required this.label,
    required this.icon,
    required this.color,
    required this.notes,
    required this.medicines,
  });
}

class _TemplateChip extends StatelessWidget {
  final _RxTemplate template;
  final VoidCallback onTap;
  const _TemplateChip({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: template.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: template.color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(template.icon, size: 16, color: template.color),
            const SizedBox(width: 7),
            Text(
              template.label,
              style: AppTextStyles.body(
                  size: 13, weight: FontWeight.w600, color: template.color),
            ),
            const SizedBox(width: 5),
            Text(
              '${template.medicines.length} meds',
              style: AppTextStyles.label(template.color.withValues(alpha: 0.65)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vitals Section ────────────────────────────────────────────────────────────

class _VitalsSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final TextEditingController systolicCtrl;
  final TextEditingController diastolicCtrl;
  final TextEditingController tempCtrl;
  final TextEditingController pulseCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController spo2Ctrl;
  final TextEditingController sugarCtrl;

  const _VitalsSection({
    required this.expanded,
    required this.onToggle,
    required this.systolicCtrl,
    required this.diastolicCtrl,
    required this.tempCtrl,
    required this.pulseCtrl,
    required this.weightCtrl,
    required this.spo2Ctrl,
    required this.sugarCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: expanded ? const Color(0xFFF0FBF7) : SevaCareColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: expanded ? SevaCareColors.mint : SevaCareColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: expanded ? SevaCareColors.mint.withValues(alpha: 0.15) : SevaCareColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.monitor_heart_outlined, size: 16,
                      color: expanded ? SevaCareColors.mint : SevaCareColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Record Patient Vitals',
                          style: AppTextStyles.body(size: 13, weight: FontWeight.w600,
                              color: expanded ? SevaCareColors.mintForeground : SevaCareColors.primary)),
                      Text('BP · Temperature · Weight · Pulse · SpO₂',
                          style: AppTextStyles.label(SevaCareColors.textMuted)),
                    ],
                  ),
                ),
                Icon(expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20, color: SevaCareColors.textMuted),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _VitalInput(label: 'Systolic BP', unit: 'mmHg', ctrl: systolicCtrl, hint: '120')),
                  const SizedBox(width: 12),
                  Expanded(child: _VitalInput(label: 'Diastolic BP', unit: 'mmHg', ctrl: diastolicCtrl, hint: '80')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _VitalInput(label: 'Temperature', unit: '°C', ctrl: tempCtrl, hint: '37.0')),
                  const SizedBox(width: 12),
                  Expanded(child: _VitalInput(label: 'Pulse Rate', unit: 'bpm', ctrl: pulseCtrl, hint: '72')),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _VitalInput(label: 'Weight', unit: 'kg', ctrl: weightCtrl, hint: '70')),
                  const SizedBox(width: 12),
                  Expanded(child: _VitalInput(label: 'SpO₂', unit: '%', ctrl: spo2Ctrl, hint: '98')),
                ]),
                const SizedBox(height: 10),
                _VitalInput(label: 'Blood Sugar', unit: 'mg/dL', ctrl: sugarCtrl, hint: '110'),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VitalInput extends StatelessWidget {
  final String label;
  final String unit;
  final TextEditingController ctrl;
  final String hint;

  const _VitalInput({required this.label, required this.unit, required this.ctrl, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(SevaCareColors.textMuted)),
        const SizedBox(height: 4),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: AppTextStyles.inputText(SevaCareColors.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint(SevaCareColors.textMuted.withValues(alpha: 0.5)),
            suffixText: unit,
            suffixStyle: AppTextStyles.label(SevaCareColors.mint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SevaCareColors.border, width: 1.5)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SevaCareColors.border, width: 1.5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: SevaCareColors.mint, width: 2)),
            filled: true,
            fillColor: SevaCareColors.surface,
          ),
        ),
      ],
    );
  }
}

// ── Common Indian medicines for autocomplete ──────────────────────────────────

const _kCommonMedicines = <String>[
  'Paracetamol', 'Ibuprofen', 'Diclofenac', 'Aspirin', 'Tramadol', 'Mefenamic Acid',
  'Dolo 650', 'Crocin', 'Combiflam', 'Ketorolac',
  'Amoxicillin', 'Azithromycin', 'Ciprofloxacin', 'Doxycycline', 'Cefixime', 'Ceftriaxone',
  'Metronidazole', 'Clarithromycin', 'Levofloxacin', 'Clindamycin', 'Amoxicillin-Clavulanate',
  'Cefuroxime', 'Co-Amoxiclav', 'Ofloxacin', 'Tinidazole',
  'Pantoprazole', 'Omeprazole', 'Rabeprazole', 'Esomeprazole', 'Metoclopramide', 'Domperidone',
  'Ondansetron', 'Sucralfate', 'Lactulose', 'Bisacodyl', 'Loperamide', 'Pan 40', 'Domstal',
  'Gelusil', 'Digene',
  'Ambroxol', 'Bromhexine', 'Salbutamol', 'Montelukast', 'Cetirizine', 'Loratadine',
  'Fexofenadine', 'Beclomethasone', 'Budesonide', 'Dextromethorphan', 'Guaifenesin',
  'Levocetrizine', 'Chlorpheniramine',
  'Amlodipine', 'Telmisartan', 'Losartan', 'Enalapril', 'Ramipril', 'Atenolol', 'Metoprolol',
  'Carvedilol', 'Furosemide', 'Hydrochlorothiazide', 'Spironolactone', 'Atorvastatin',
  'Rosuvastatin', 'Clopidogrel',
  'Metformin', 'Glimepiride', 'Glipizide', 'Sitagliptin', 'Vildagliptin', 'Dapagliflozin',
  'Empagliflozin', 'Insulin Glargine', 'Insulin Regular',
  'Levothyroxine', 'Prednisolone', 'Methylprednisolone', 'Dexamethasone', 'Hydrocortisone',
  'Vitamin D3', 'Vitamin B12', 'Calcium Carbonate', 'Ferrous Sulphate', 'Folic Acid', 'Zinc',
  'Vitamin C', 'Multivitamin', 'Becosules', 'Zincovit', 'Neurobion', 'Shelcal',
  'Sertraline', 'Escitalopram', 'Fluoxetine', 'Alprazolam', 'Clonazepam', 'Zolpidem',
  'Pregabalin', 'Gabapentin', 'Amitriptyline', 'Levetiracetam',
  'Fluconazole', 'Itraconazole', 'Clotrimazole', 'Acyclovir', 'Oseltamivir',
  'Etoricoxib', 'Celecoxib', 'Tizanidine', 'Baclofen', 'Diclofenac Gel',
  'Hydrocortisone Cream', 'Betamethasone Cream', 'Calamine', 'Ketoconazole Cream',
  'Tamsulosin', 'Finasteride', 'Sildenafil',
];

