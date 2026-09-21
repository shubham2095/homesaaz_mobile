// lib/features/auth/login_screen.dart
//
// Mirrors web `resources/views/auth/login.blade.php` +
// `public/assets/css/homesaaz.css` (.hs-card / .hs-actions / .hs-btn* /
// .hs-login-form / .hs-field / .hs-submit): a landing card with 4 entry
// buttons, where tapping "Login" reveals the inline username/password form.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstname = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  bool _showForm = false;

  @override
  void dispose() {
    _firstname.dispose();
    _password.dispose();
    super.dispose();
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final ok = await ref
        .read(authControllerProvider.notifier)
        .login(firstname: _firstname.text.trim(), password: _password.text);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      final err = ref.read(authControllerProvider).error ?? 'Login failed.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(err)));
    }
    // success -> router redirect takes over
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

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        key: const ValueKey('form'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Login',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Hs.ink,
            ),
          ),
          const SizedBox(height: 14),
          _label('Username'),
          TextFormField(
            controller: _firstname,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: _fieldDecoration(),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          _label('Password'),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _submit(),
            decoration: _fieldDecoration().copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFF0B6EA8),
              ),
              onPressed: _comingSoon,
              child: const Text(
                'Forgot Password?',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Hs.blueBorder,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('LOGIN', style: TextStyle(letterSpacing: .5)),
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
                        child: _showForm ? _form() : _landing(),
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
