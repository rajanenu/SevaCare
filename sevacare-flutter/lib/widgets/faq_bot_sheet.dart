import 'package:flutter/material.dart';
import '../core/faq/faq_data.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../data/models/models.dart';

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
  const _Msg(this.text, {required this.isBot});
}

class FaqBotSheet extends StatefulWidget {
  final UserRole? role;
  const FaqBotSheet({super.key, required this.role});

  @override
  State<FaqBotSheet> createState() => _FaqBotSheetState();
}

class _FaqBotSheetState extends State<FaqBotSheet> {
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
                    itemBuilder: (_, i) => _Bubble(msg: _messages[i]),
                  ),
                ),
                if (_suggestions.isNotEmpty) _suggestionRow(),
                _inputBar(),
              ],
            ),
          );
        },
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
