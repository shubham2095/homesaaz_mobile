// lib/features/auth/login_screen.dart
//
// Mirrors web `resources/views/auth/login.blade.php` +
// `public/assets/css/homesaaz.css` (.hs-card / .hs-actions / .hs-btn* /
// .hs-login-form / .hs-field / .hs-submit): a landing card with 4 entry
// buttons, where tapping "Login" reveals the inline login form.
//
// Login is mobile number + SMS OTP, in two steps like the web: enter the
// number -> "SEND OTP", then enter the 6-digit OTP -> "LOGIN".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../widgets/phone_input_formatter.dart';
import 'auth_controller.dart';

/// Backend OTP length / resend gap (config/auth_otp.php).
const _otpLength = 6;
const _resendSeconds = 30;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _otp = TextEditingController();

  bool _showForm = false;
  bool _otpSent = false;
  bool _sending = false;
  bool _verifying = false;
  int _cooldown = 0;
  Timer? _timer;

  /// Set only while the server is in OTP TEST MODE (SMS not live yet).
  String? _debugOtp;

  @override
  void initState() {
    super.initState();
    // Signed out by the server (e.g. this number logged in elsewhere) —
    // say so once, then open straight onto the login form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final err = ref.read(authControllerProvider).error;
      if (err != null && mounted) {
        setState(() => _showForm = true);
        _snack(err);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  void _comingSoon() => _snack('Coming soon');

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _sendOtp() async {
    if (!_phoneKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    final res =
        await ref.read(authControllerProvider.notifier).sendOtp(_phone.text);

    if (!mounted) return;
    setState(() => _sending = false);
    if (res.error != null) {
      _snack(res.error!);
      return;
    }
    _otp.clear();
    setState(() {
      _otpSent = true;
      _debugOtp = res.debugOtp;
    });
    _startCooldown();
    _snack('OTP sent to your mobile number.');
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (_otp.text.length != _otpLength) {
      _snack('Enter the $_otpLength-digit OTP.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _verifying = true);

    final ok = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(phone: _phone.text, otp: _otp.text);

    if (!mounted) return;
    setState(() => _verifying = false);

    if (!ok) {
      final err = ref.read(authControllerProvider).error ?? 'Login failed.';
      _otp.clear();
      _snack(err);
    }
    // success -> router redirect takes over
  }

  void _changeNumber() {
    _timer?.cancel();
    _otp.clear();
    setState(() {
      _otpSent = false;
      _cooldown = 0;
      _debugOtp = null;
    });
  }

  /// Web's "TEST MODE (local only): OTP = …" box. Tap it to fill the field.
  Widget _debugOtpBanner(String otp) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _otp.text = otp,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3CD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE7D977)),
          ),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 13, color: Hs.ink),
              children: [
                const TextSpan(
                    text: 'TEST MODE: ',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const TextSpan(text: 'OTP = '),
                TextSpan(
                    text: otp,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
                const TextSpan(
                    text: '  (tap to fill)',
                    style: TextStyle(fontSize: 11.5, color: Hs.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration() => InputDecoration(
    filled: true,
    fillColor: const Color(0xFFFFFEF2),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFCBB94F)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Hs.blueBorder, width: 2),
    ),
  );

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Hs.ink,
          ),
          children: [
            TextSpan(text: text),
            const TextSpan(text: '  *', style: TextStyle(color: Hs.red)),
          ],
        ),
      ),
    ),
  );

  /// One of the 4 landing-screen entry buttons (web `.hs-btn`).
  Widget _entryButton({
    required String label,
    required Color fill,
    required Color border,
    required VoidCallback? onTap,
    bool disabled = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
                color: Hs.ink.withValues(alpha: disabled ? .55 : 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _landing() {
    return Column(
      key: const ValueKey('landing'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _entryButton(
          label: 'Login',
          fill: Hs.blueSoft,
          border: Hs.blueBorder,
          onTap: () => setState(() => _showForm = true),
        ),
        const SizedBox(height: 16),
        _entryButton(
          label: 'Supplier Request',
          fill: Hs.blueSoft,
          border: Hs.blueBorder,
          onTap: _comingSoon,
        ),
        const SizedBox(height: 16),
        _entryButton(
          label: 'Customer Request',
          fill: Hs.pinkSoft,
          border: Hs.pinkBorder,
          onTap: _comingSoon,
        ),
        const SizedBox(height: 16),
        _entryButton(
          label: 'Coming soon',
          fill: Hs.greenSoft,
          border: Hs.greenBorder,
          onTap: null,
          disabled: true,
        ),
      ],
    );
  }

  Widget _spinner() => const SizedBox(
    height: 22,
    width: 22,
    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
  );

  ButtonStyle get _submitStyle => FilledButton.styleFrom(
    backgroundColor: Hs.blueBorder,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  Widget _title() => const Text(
    'Login',
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Hs.ink),
  );

  /// Step 1 — mobile number.
  Widget _phoneStep() {
    return Form(
      key: _phoneKey,
      child: Column(
        key: const ValueKey('phone'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(),
          const SizedBox(height: 14),
          _label('Mobile Number'),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [PhoneInputFormatter()],
            onFieldSubmitted: (_) => _sendOtp(),
            style: const TextStyle(fontSize: 16, letterSpacing: 1),
            decoration: _fieldDecoration().copyWith(
              hintText: '10-digit mobile number',
              prefixText: '+91  ',
              prefixStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Hs.ink),
            ),
            validator: (v) => RegExp(r'^[6-9]\d{9}$').hasMatch(v ?? '')
                ? null
                : 'Enter a valid 10-digit mobile number',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: _submitStyle,
              onPressed: _sending ? null : _sendOtp,
              child: _sending
                  ? _spinner()
                  : const Text('SEND OTP', style: TextStyle(letterSpacing: .5)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF555555)),
            onPressed: () => setState(() => _showForm = false),
            child: const Text('← Back', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  /// Step 2 — the OTP that was texted to that number.
  Widget _otpStep() {
    final p = _phone.text;
    final masked = p.length >= 4 ? '******${p.substring(p.length - 4)}' : p;
    return Column(
      key: const ValueKey('otp'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(),
        const SizedBox(height: 10),
        Text('OTP sent to $masked',
            style: const TextStyle(fontSize: 13, color: Hs.inkSoft)),
        const SizedBox(height: 14),
        if (_debugOtp != null) _debugOtpBanner(_debugOtp!),
        _label('OTP'),
        TextField(
          controller: _otp,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          autofocus: true,
          maxLength: _otpLength,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 10),
          decoration: _fieldDecoration().copyWith(counterText: ''),
          onChanged: (v) {
            // Log in as soon as the last digit is typed / auto-filled.
            if (v.length == _otpLength) _verify();
          },
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: _submitStyle,
            onPressed: _verifying ? null : _verify,
            child: _verifying
                ? _spinner()
                : const Text('LOGIN', style: TextStyle(letterSpacing: .5)),
          ),
        ),
        const SizedBox(height: 8),
        // Both links share the card's width (Flexible + scaleDown) so a
        // narrow phone or a long "Resend OTP in 30s" label can't overflow.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF555555),
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: _changeNumber,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('← Change number',
                      maxLines: 1, style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton(
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0B6EA8),
                    padding: const EdgeInsets.symmetric(horizontal: 6)),
                onPressed: (_cooldown > 0 || _sending) ? null : _sendOtp,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _cooldown > 0
                        ? 'Resend OTP in ${_cooldown}s'
                        : 'Resend OTP',
                    maxLines: 1,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Hs.slow,
              curve: Hs.curve,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(
                  offset: Offset(0, (1 - v) * 18),
                  child: child,
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    color: Hs.yellowDeep,
                    border: Border.all(color: Hs.yellowBorder),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(26, 28, 26, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/homesaaz_logo.png',
                        width: 230,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: Hs.med,
                        switchInCurve: Hs.curve,
                        switchOutCurve: Hs.curve,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SizeTransition(
                            sizeFactor: anim,
                            child: child,
                          ),
                        ),
                        child: !_showForm
                            ? _landing()
                            : (_otpSent ? _otpStep() : _phoneStep()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
