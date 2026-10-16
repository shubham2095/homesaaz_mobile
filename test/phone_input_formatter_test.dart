import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/widgets/phone_input_formatter.dart';

TextEditingValue v(String text, [int? cursor]) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor ?? text.length),
    );

void main() {
  final f = PhoneInputFormatter();

  test('a pasted +91 number keeps the last 10 digits', () {
    final r = f.formatEditUpdate(v(''), v('+91 98765-43210'));
    expect(r.text, '9876543210');
  });

  test('a 12-digit paste (91 + number) keeps the last 10 digits', () {
    final r = f.formatEditUpdate(v(''), v('919876543210'));
    expect(r.text, '9876543210');
  });

  test('typing an 11th digit is ignored, not shifted in', () {
    final r = f.formatEditUpdate(v('9876543210'), v('98765432101'));
    expect(r.text, '9876543210');
  });

  test('letters and symbols are dropped', () {
    final r = f.formatEditUpdate(v('98'), v('98a-'));
    expect(r.text, '98');
  });

  test('editing in the middle keeps the cursor in place', () {
    // "9876543210" -> a digit deleted after the 3rd character.
    final r = f.formatEditUpdate(v('9876543210', 4), v('987543210', 3));
    expect(r.text, '987543210');
    expect(r.selection.baseOffset, 3);
  });
}
