import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/faq/faq_data.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/error_utils.dart';
import '../data/models/models.dart';
import '../providers/app_state.dart';

/// Opens the SevaCare Assistant as a modal chat sheet. Rule-based and offline —
/// it answers predefined, role-aware questions from [kFaqEntries].
Future<void> showFaqBot(BuildContext context, UserRole? role) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => FaqBotSheet(role: role),
  );
}

/// Returns the best-matching FAQ entry for a free-text query, or null when
/// nothing clears the confidence threshold.
FaqEntry? matchFaq(String input, List<FaqEntry> pool) {
  final q = input.toLowerCase().trim();
  if (q.isEmpty) return null;
  FaqEntry? best;
  var bestScore = 0;
  for (final e in pool) {
    var score = 0;
    if (e.question.toLowerCase() == q) score += 100;
    for (final kw in e.keywords) {
      if (q.contains(kw)) score += kw.contains(' ') ? 3 : 2;
    }
    if (score > bestScore) {
      bestScore = score;
      best = e;
    }
  }
  return bestScore >= 2 ? best : null;
}

class _Msg {
  final String text;
  final bool isBot;
  final bool isBookingForm;
  const _Msg(this.text, {required this.isBot, this.isBookingForm = false});
}

class FaqBotSheet extends ConsumerStatefulWidget {
  final UserRole? role;
  const FaqBotSheet({super.key, required this.role});

  @override
  ConsumerState<FaqBotSheet> createState() => _FaqBotSheetState();
}

class _FaqBotSheetState extends ConsumerState<FaqBotSheet> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_Msg> _messages = [];
  late final List<FaqEntry> _pool;

  @override
  void initState() {
    super.initState();
    final audience = audienceForRole(widget.role);
    _pool = kFaqEntries
        .where((e) =>
            e.audiences.contains(FaqAudience.everyone) ||
            e.audiences.contains(audience))
        .toList();
    _messages.add(const _Msg(
      "Hi! I'm the SevaCare Assistant 🤖 — ask me anything, or tap a suggestion below.",
      isBot: true,
    ));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Remaining suggestions the user hasn't asked yet (keeps the chip row fresh).
  List<FaqEntry> get _suggestions {
    final asked = _messages.where((m) => !m.isBot).map((m) => m.text).toSet();
    return _pool.where((e) => !asked.contains(e.question)).take(6).toList();
  }

  void _ask(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final match = matchFaq(trimmed, _pool);
    setState(() {
      _messages.add(_Msg(trimmed, isBot: false));
      _messages.add(_Msg(
        match?.answer ??
            "I'm not sure about that one 🤔. Try one of the suggestions below, or "
                'scroll down on the Help screen to send a message to support.',
        isBot: true,
      ));
      _inputCtrl.clear();
    });
    _scrollToBottom();
  }

  void _openBookingForm() {
    setState(() {
      _messages.add(const _Msg('', isBot: true, isBookingForm: true));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final hospital = ref.watch(hospitalProvider);
    final tenantPublicId = hospital.tenantPublicId;
    // Both id AND name must be set: restore() from a previous session leaves
    // the name empty, and a stale restored tenant must NOT count as "selected"
    // — otherwise the booking silently lands in a hospital the user never
    // picked this session.
    final hospitalSelected =
        tenantPublicId.isNotEmpty && hospital.hospitalName.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) {
          return Container(
            decoration: const BoxDecoration(
              color: SevaCareColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      if (msg.isBookingForm) {
                        return _BookingFormBubble(
                          tenantPublicId: tenantPublicId,
                          hospitalName: hospital.hospitalName.trim(),
                        );
                      }
                      return _Bubble(msg: msg);
                    },
                  ),
                ),
                // Book Appointment is only offered once a hospital is
                // explicitly selected from the list this session — without a
                // confirmed tenant the request could land in the wrong
                // hospital's inbox.
                if (hospitalSelected) _bookAppointmentRow(hospital.hospitalName.trim()),
                if (_suggestions.isNotEmpty) _suggestionRow(),
                _inputBar(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _bookAppointmentRow(String hospitalName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        // Filled mint chip — visually distinct from the purple question
        // suggestions so "book" reads as an action, not another FAQ.
        child: ActionChip(
          avatar: const Icon(Icons.calendar_month_rounded, size: 16, color: Colors.white),
          label: Text('Book Appointment at $hospitalName',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label(Colors.white).copyWith(fontWeight: FontWeight.w700)),
          backgroundColor: SevaCareColors.mint,
          side: BorderSide.none,
          onPressed: _openBookingForm,
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: SevaCareColors.heroGradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white24,
            child: Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SevaCare Assistant',
                    style: AppTextStyles.buttonLabel(Colors.white)),
                Text('Answers common questions',
                    style: AppTextStyles.label(
                        Colors.white.withValues(alpha: 0.8))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _suggestionRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final e = _suggestions[i];
          return ActionChip(
            label: Text(e.question, style: AppTextStyles.label(SevaCareColors.primary)),
            backgroundColor: SevaCareColors.primarySoft,
            side: BorderSide(color: SevaCareColors.primary.withValues(alpha: 0.25)),
            onPressed: () => _ask(e.question),
          );
        },
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                textInputAction: TextInputAction.send,
                onSubmitted: _ask,
                decoration: InputDecoration(
                  hintText: 'Ask a question…',
                  filled: true,
                  fillColor: SevaCareColors.surface,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: SevaCareColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: SevaCareColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: SevaCareColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _ask(_inputCtrl.text),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isBot = msg.isBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isBot ? SevaCareColors.surface : SevaCareColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isBot ? 4 : 16),
            bottomRight: Radius.circular(isBot ? 16 : 4),
          ),
          border: isBot ? Border.all(color: SevaCareColors.border) : null,
        ),
        child: Text(
          msg.text,
          style: AppTextStyles.bodyText(
            isBot ? SevaCareColors.text : Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Inline booking form rendered as a bot bubble once the user taps
/// "Book Appointment". Mirrors the QR portal fields (name, mobile, age,
/// doctor, date, symptoms) — the request goes straight to the chosen
/// doctor's inbox and is auto-confirmed with the next available token.
class _BookingFormBubble extends ConsumerStatefulWidget {
  final String tenantPublicId;
  final String hospitalName;
  const _BookingFormBubble({required this.tenantPublicId, required this.hospitalName});

  @override
  ConsumerState<_BookingFormBubble> createState() => _BookingFormBubbleState();
}

class _BookingFormBubbleState extends ConsumerState<_BookingFormBubble> {
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _symptomsCtrl = TextEditingController();
  List<DoctorSummary> _doctors = [];
  String? _doctorPublicId;
  DateTime _preferredDate = DateTime.now();
  bool _submitting = false;
  bool _submitted = false;
  String? _assignedToken;
  String? _requestPublicId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final doctors =
          await ref.read(repositoryProvider).listPublicDoctors(widget.tenantPublicId);
      if (mounted) setState(() => _doctors = doctors);
    } catch (_) {
      // Dropdown stays empty; the backend falls back to the first active doctor.
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _ageCtrl.dispose();
    _symptomsCtrl.dispose();
    super.dispose();
  }

  String get _dateLabel =>
      '${_preferredDate.year}-${_preferredDate.month.toString().padLeft(2, '0')}-${_preferredDate.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 14)),
    );
    if (picked != null && mounted) setState(() => _preferredDate = picked);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final mobileDigits = _mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.');
      return;
    }
    if (mobileDigits.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number.');
      return;
    }
    if (age <= 0 || age > 120) {
      setState(() => _error = 'Please enter a valid age.');
      return;
    }
    if (_doctors.isNotEmpty && (_doctorPublicId == null || _doctorPublicId!.isEmpty)) {
      setState(() => _error = 'Please choose a doctor.');
      return;
    }
    if (_symptomsCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please describe your symptoms.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ref.read(repositoryProvider).submitQuickBookingRequest(
            widget.tenantPublicId,
            patientName: name,
            patientMobile: mobileDigits,
            patientAge: age,
            doctorPublicId: _doctorPublicId,
            preferredDate: _dateLabel,
            symptoms: _symptomsCtrl.text,
          );
      if (mounted) {
        setState(() {
          _submitting = false;
          _submitted = true;
          _requestPublicId = result['requestPublicId'] as String?;
          _assignedToken = result['requestStatus'] == 'confirmed'
              ? result['assignedSlot'] as String?
              : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = extractErrorMessage(e, fallback: 'Failed to submit. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        decoration: BoxDecoration(
          color: SevaCareColors.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: SevaCareColors.border),
        ),
        child: _submitted ? _successContent() : _formContent(),
      ),
    );
  }

  /// Mirrors the QR portal's confirmation page: green tick, the token in a
  /// prominent pill, and the request ID. A chatbot booking is the same booking,
  /// so it must land with the same certainty.
  Widget _successContent() {
    final confirmed = _assignedToken != null && _assignedToken!.isNotEmpty;
    final hospital = widget.hospitalName.isNotEmpty ? widget.hospitalName : 'the hospital';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: confirmed
                    ? const Color(0xFFE7F8F0)
                    : SevaCareColors.primarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                confirmed ? Icons.check_rounded : Icons.schedule_rounded,
                size: 20,
                color: confirmed ? const Color(0xFF12A150) : SevaCareColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                confirmed ? 'Appointment Confirmed!' : 'Request Submitted!',
                style: AppTextStyles.bodyText(SevaCareColors.text)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (confirmed) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: SevaCareColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _assignedToken!,
              style: AppTextStyles.bodyText(SevaCareColors.primary)
                  .copyWith(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your token is booked. Show this token number at $hospital reception on your visit.',
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
        ] else
          Text(
            'Your request has been sent to the doctor. They will review it and confirm your slot. '
            '$hospital will contact you on ${_mobileCtrl.text.trim()}.',
            style: AppTextStyles.label(SevaCareColors.textMuted),
          ),
        if (_requestPublicId != null && _requestPublicId!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SevaCareColors.background,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: SevaCareColors.border),
            ),
            child: Text('Request ID: ${_requestPublicId!}',
                style: AppTextStyles.label(SevaCareColors.textMuted)),
          ),
        ],
      ],
    );
  }

  Widget _formContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Book Appointment', style: AppTextStyles.bodyText(SevaCareColors.text).copyWith(fontWeight: FontWeight.w700)),
        if (widget.hospitalName.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text('🏥 ${widget.hospitalName}', style: AppTextStyles.label(SevaCareColors.textMuted)),
        ],
        const SizedBox(height: 10),
        _field(_nameCtrl, 'Full Name *', TextInputType.name),
        const SizedBox(height: 8),
        _field(_mobileCtrl, 'Mobile Number *', TextInputType.phone),
        const SizedBox(height: 8),
        _field(_ageCtrl, 'Age *', TextInputType.number),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _doctorPublicId,
          isExpanded: true,
          style: AppTextStyles.bodyText(SevaCareColors.text),
          decoration: _inputDecoration('Select Doctor *'),
          items: _doctors
              .map((d) => DropdownMenuItem(
                    value: d.doctorPublicId,
                    child: Text(
                      'Dr. ${d.name}${d.specialty.isNotEmpty ? ' — ${d.specialty}' : ''}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _doctorPublicId = v),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(10),
          child: InputDecorator(
            decoration: _inputDecoration('Preferred Date *'),
            child: Row(
              children: [
                const Icon(Icons.event_outlined, size: 16, color: SevaCareColors.textMuted),
                const SizedBox(width: 8),
                Text(_dateLabel, style: AppTextStyles.bodyText(SevaCareColors.text)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _field(_symptomsCtrl, 'Symptoms / Reason for Visit *', TextInputType.text, maxLines: 2),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppTextStyles.label(SevaCareColors.danger)),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: SevaCareColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Request Appointment'),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      isDense: true,
      filled: true,
      fillColor: SevaCareColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: SevaCareColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: SevaCareColors.border),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, TextInputType type,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      style: AppTextStyles.bodyText(SevaCareColors.text),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: SevaCareColors.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SevaCareColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: SevaCareColors.border),
        ),
      ),
    );
  }
}
