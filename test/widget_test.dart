import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/features/auth/login_screen.dart';

void main() {
  testWidgets('login screen opens the mobile-number step', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // Landing card first; "Login" reveals the form.
    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // The label is a RichText ("Mobile Number" + a red "*").
    expect(find.textContaining('Mobile Number', findRichText: true),
        findsOneWidget);
    expect(find.text('SEND OTP'), findsOneWidget);
  });
}
