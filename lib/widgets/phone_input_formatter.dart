// lib/widgets/phone_input_formatter.dart
import 'package:flutter/services.dart';

/// Keeps digits only, at most 10 of them.
///
///  * A pasted "+91 98765 43210" / "919876543210" keeps the LAST 10 digits —
///    the same normalisation the server applies to a mobile number
///    (`OtpLoginService::normalizePhone`).
///  * Typing an 11th digit is ignored (it doesn't push the first digit out).
///  * Editing in the middle leaves the cursor where it is.
class PhoneInputFormatter extends TextInputFormatter {
  static final _nonDigits = RegExp(r'\D+');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    var digits = text.replaceAll(_nonDigits, '');

    if (digits.length > 10) {
      final oldDigits = oldValue.text.replaceAll(_nonDigits, '').length;
      final typedOneChar = oldValue.selection.isCollapsed &&
          text.length == oldValue.text.length + 1;
      // One more digit typed onto a full number: refuse it.
      if (typedOneChar && oldDigits >= 10) return oldValue;

      // Anything longer is a paste: keep the last 10 digits.
      digits = digits.substring(digits.length - 10);
      return TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
    }

    // Keep the cursor after the same digit it was after (non-digits that were
    // dropped shift the raw offset).
    final raw = newValue.selection.baseOffset;
    final offset = raw < 0
        ? digits.length
        : text.substring(0, raw.clamp(0, text.length)).replaceAll(_nonDigits, '').length;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
