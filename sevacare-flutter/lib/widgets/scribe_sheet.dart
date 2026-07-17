import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/error_utils.dart';
import '../data/models/models.dart';
import '../providers/app_state.dart';

/// The voice scribe sheet: the doctor dictates the consult, the device's own
/// speech recognition turns it into text (audio never leaves the phone), and
/// the server structures that text into a prescription draft. Pops with the
/// [ScribeDraft] for the consultation screen to pre-fill — nothing is applied
/// or saved from here, so the doctor always reviews before anything sticks.
class ScribeSheet extends ConsumerStatefulWidget {
  const ScribeSheet({super.key});

  /// Opens the sheet and resolves with the accepted draft, or null on dismiss.
  static Future<ScribeDraft?> open(BuildContext context) {
    return showModalBottomSheet<ScribeDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ScribeSheet(),
    );
  }

  @override
  ConsumerState<ScribeSheet> createState() => _ScribeSheetState();
}

class _ScribeSheetState extends ConsumerState<ScribeSheet> {
  final SpeechToText _speech = SpeechToText();
  final _transcriptCtrl = TextEditingController();

  bool _speechReady = false;
  bool _listening = false;
  bool _drafting = false;
  String? _error;
  String _localeId = 'en_IN';

  /// Text finalized in earlier listen sessions; the live session's words are
  /// appended after this so pausing and resuming never loses a sentence.
  String _committed = '';

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
        onError: (e) {
          if (mounted) setState(() => _listening = false);
        },
        onStatus: (status) {
          if (mounted && status == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (mounted) setState(() => _speechReady = ready);
    } catch (_) {
      // No recognizer on this device/browser — typing the note still works.
      if (mounted) setState(() => _speechReady = false);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_listening) {
      await _speech.stop();
      _commitSession();
      setState(() => _listening = false);
      return;
    }
    _committed = _transcriptCtrl.text.trim();
    setState(() {
      _listening = true;
      _error = null;
    });
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
    final live = result.recognizedWords;
    setState(() {
      _transcriptCtrl.text = _committed.isEmpty ? live : '$_committed $live';
    });
    if (result.finalResult) {
      _commitSession();
    }
  }

  void _commitSession() {
    _committed = _transcriptCtrl.text.trim();
  }

  Future<void> _draft() async {
    final transcript = _transcriptCtrl.text.trim();
    if (transcript.length < 10) {
      setState(() => _error = 'Dictate or type the consult first.');
      return;
    }
    if (_listening) {
      await _speech.stop();
      _commitSession();
    }
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final auth = ref.read(authProvider);
      final repo = ref.read(repositoryProvider);
      final draft = await repo.scribeDraft(
        auth.tenantPublicId ?? '',
        auth.token ?? '',
        transcript,
      );
      if (mounted) Navigator.of(context).pop(draft);
    } catch (e) {
      if (mounted) {
        setState(() {
          _drafting = false;
          _error = extractErrorMessage(e,
              fallback: 'Could not draft the prescription. Please try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + inset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_none_rounded, color: context.colors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Dictate the consult',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          Text(
            'Speak naturally — mixing English, Hindi or Telugu is fine. '
            'You review the draft before anything is saved.',
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final (id, label) in _locales)
                ChoiceChip(
                  label: Text(label),
                  selected: _localeId == id,
                  onSelected: _listening
                      ? null
                      : (_) => setState(() => _localeId = id),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _transcriptCtrl,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: _speechReady
                  ? 'Tap the mic and start speaking…'
                  : 'Speech recognition unavailable — type the consult note here.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(fontSize: 12, color: context.colors.error)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (_speechReady)
                FloatingActionButton(
                  heroTag: 'scribe_mic',
                  onPressed: _drafting ? null : _toggleListening,
                  backgroundColor:
                      _listening ? context.colors.danger : context.colors.primary,
                  child: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white),
                ),
              if (_speechReady) const SizedBox(width: 14),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _drafting ? null : _draft,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _drafting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_drafting ? 'Drafting…' : 'Draft prescription'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
