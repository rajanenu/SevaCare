import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// PII shown masked by default — "98••••••65" — with an eye toggle to reveal.
/// A pharmacy counter or reception screen is visible to whoever is standing at
/// it; a customer's mobile number shouldn't be, unless the operator asks.
class MaskedText extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final int visiblePrefix;
  final int visibleSuffix;

  const MaskedText(
    this.value, {
    super.key,
    this.style,
    this.visiblePrefix = 2,
    this.visibleSuffix = 2,
  });

  @override
  State<MaskedText> createState() => _MaskedTextState();
}

class _MaskedTextState extends State<MaskedText> {
  bool _revealed = false;

  String get _masked {
    final v = widget.value;
    if (v.length <= widget.visiblePrefix + widget.visibleSuffix) {
      return '•' * v.length;
    }
    return v.substring(0, widget.visiblePrefix) +
        '•' * (v.length - widget.visiblePrefix - widget.visibleSuffix) +
        v.substring(v.length - widget.visibleSuffix);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value.isEmpty) return const SizedBox.shrink();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(_revealed ? widget.value : _masked, style: widget.style),
      const SizedBox(width: 2),
      InkWell(
        onTap: () => setState(() => _revealed = !_revealed),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 14,
            color: SevaCareColors.textMuted,
          ),
        ),
      ),
    ]);
  }
}
