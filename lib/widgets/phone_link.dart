// lib/widgets/phone_link.dart
//
// A phone number styled and behaving like the web app's `<a href="tel:…">`
// links — tap opens the device's dialer (pre-filled, not an automatic call;
// the person still has to press call themselves, same as the web).
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/tokens.dart';

class PhoneLink extends StatelessWidget {
  const PhoneLink(
    this.number, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String number;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  Future<void> _call(BuildContext context) async {
    final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('No dialer app found.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = number.trim();
    if (trimmed.isEmpty || trimmed == '-') {
      return Text(trimmed.isEmpty ? '-' : trimmed, style: style);
    }
    return InkWell(
      onTap: () => _call(context),
      child: Text(
        trimmed,
        maxLines: maxLines,
        overflow: overflow,
        style: style ??
            const TextStyle(color: Hs.blue, fontWeight: FontWeight.w600),
      ),
    );
  }
}
