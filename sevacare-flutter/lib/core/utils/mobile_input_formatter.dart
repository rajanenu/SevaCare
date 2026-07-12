import 'package:flutter/services.dart';

/// Keeps a mobile-number field to digits only, drops one leading "0" (some
/// people type it out of habit before their 10-digit number), and caps the
/// result at 10 digits — the general Indian mobile-number shape everywhere in
/// the app, not just pharmacy.
class MobileInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
