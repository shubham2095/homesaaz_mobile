// lib/widgets/phone_input_formatter.dart
import 'package:flutter/services.dart';

/// Keeps digits only and, for a pasted "+91 98765 43210" / "919876543210",
/// the LAST 10 of them — the same normalisation the server applies to a
/// mobile number (`OtpLoginService::normalizePhone`).
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D+'), '');
    if (digits.length > 10) digits = digits.substring(digits.length - 10);
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
