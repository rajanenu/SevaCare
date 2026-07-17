import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/voice/voice_command.dart';
import '../data/models/models.dart';

/// A universal "speak to the app" sheet. The user taps the mic, says what they
/// want ("book an appointment", "my prescriptions", "find a cardiologist"), and
/// the device's own speech recognition turns it into text (audio never leaves
/// the phone). [VoiceCommand] resolves that text to a [VoiceAction]; the sheet
/// pops with it and the caller navigates. Anything unrecognised becomes a
/// search, so the mic always leads somewhere useful.
class VoiceCommandSheet extends ConsumerStatefulWidget {
  final UserRole? role;
  final String searchRoute;

  const VoiceCommandSheet({
    super.key,
    required this.role,
    required this.searchRoute,
  });

  /// Opens the sheet and resolves with the chosen [VoiceAction], or null if the
  /// user dismissed it without saying anything.
  static Future<VoiceAction?> open(
    BuildContext context, {
    required UserRole? role,
    required String searchRoute,
  }) {
    return showModalBottomSheet<VoiceAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VoiceCommandSheet(role: role, searchRoute: searchRoute),
    );
  }

  @override
  ConsumerState<VoiceCommandSheet> createState() => _VoiceCommandSheetState();
}

class _VoiceCommandSheetState extends ConsumerState<VoiceCommandSheet> {
  final SpeechToText _speech = SpeechToText();
  final _ctrl = TextEditingController();

  bool _speechReady = false;
  bool _checkedSpeech = false;
  bool _listening = false;
  String _localeId = 'en_IN';

  static const _locales = [
    ('en_IN', 'English'),
    ('hi_IN', 'हिन्दी'),
    ('te_IN', 'తెలుగు'),
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      final ready = await _speech.initialize(
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (mounted && status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (mounted) {
        setState(() {
          _speechReady = ready;
          _checkedSpeech = true;
        });
        if (ready) _toggleListening(); // start hands-free
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _speechReady = false;
          _checkedSpeech = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: _onSpeech,
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        localeId: _localeId,
      ),
    );
  }

  void _onSpeech(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _ctrl.text = result.recognizedWords);
    // A final result with real words → act on it automatically.
    if (result.finalResult && result.recognizedWords.trim().length > 1) {
      _submit();
    }
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    if (_listening) await _speech.stop();
    final action = VoiceCommand.resolve(
      transcript: text,
      role: widget.role,
      searchRoute: widget.searchRoute,
    );
    if (mounted) Navigator.of(context).pop(action);
  }

  List<String> get _examples => switch (widget.role) {
        UserRole.patient => [
            'Book an appointment',
            'My prescriptions',
            'Find a cardiologist',
          ],
        UserRole.doctor => [
            'Open my queue',
            'Booking requests',
            'Start consultation',
          ],
        UserRole.admin => [
            'Show reports',
            'My doctors',
            'Staff',
          ],
        UserRole.staff => [
            'Register a patient',
            'Front desk',
            'Notifications',
          ],
        _ => ['Search', 'Notifications', 'Settings'],
      };

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final hasText = _ctrl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grabber
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: context.colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _listening ? 'Listening…' : 'Speak to SevaCare',
                  style: AppTextStyles.cardTitle(context.colors.text),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          Text(
            'Say what you want to do — book, search, or open a screen. '
            'Works in English, हिन्दी or తెలుగు.',
            style: AppTextStyles.body(size: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 14),

          // Language chips
          Wrap(
            spacing: 8,
            children: [
              for (final (id, label) in _locales)
                ChoiceChip(
                  label: Text(label),
                  selected: _localeId == id,
                  onSelected: _listening ? null : (_) => setState(() => _localeId = id),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Transcript / manual entry (also the typed fallback if no mic)
          TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            style: AppTextStyles.inputText(context.colors.text),
            decoration: InputDecoration(
              hintText: _checkedSpeech && !_speechReady
                  ? 'Type what you need…'
                  : 'Tap the mic and start speaking…',
              hintStyle: AppTextStyles.inputText(context.colors.textMuted),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 12),

          // Example prompts
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ex in _examples)
                GestureDetector(
                  onTap: () {
                    _ctrl.text = ex;
                    _submit();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.colors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      ex,
                      style: AppTextStyles.body(
                          size: 12,
                          weight: FontWeight.w600,
                          color: context.colors.primary),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              if (_speechReady)
                _MicButton(
                  listening: _listening,
                  onTap: _toggleListening,
                ),
              if (_speechReady) const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: hasText ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Go'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The pulsing mic FAB — red halo while listening.
class _MicButton extends StatefulWidget {
  final bool listening;
  final VoidCallback onTap;
  const _MicButton({required this.listening, required this.onTap});

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.listening ? context.colors.danger : context.colors.primary;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final glow = widget.listening ? 0.25 + 0.20 * _pulse.value : 0.30;
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: glow),
                  blurRadius: widget.listening ? 22 : 12,
                  spreadRadius: widget.listening ? 2 : 0,
                ),
              ],
            ),
            child: Icon(
              widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
