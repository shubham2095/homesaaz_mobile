// lib/features/users/user_form.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/states.dart';
import 'access_editor.dart';
import 'user_repository.dart';

/// Opens the add / edit sheet. Returns `true` if a change was saved.
Future<bool?> showUserForm(BuildContext context, {int? userId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _UserForm(userId: userId),
  );
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({this.userId});
  final int? userId;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _pwd = TextEditingController();
  // null = not chosen yet — the web form has no default role either, and
  // makes picking one required.
  int? _role;
  XFile? _pickedImage;
  String? _existingImage;
  AccessSelection _access = AccessSelection();

  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _pwd.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m = await ref.read(userRepositoryProvider).getUser(widget.userId!);
      _first.text = '${m['FirstName'] ?? ''}';
      _last.text = '${m['LastName'] ?? ''}';
      _email.text = '${m['EmailID'] ?? ''}';
      _role = (m['user_role'] is num)
          ? (m['user_role'] as num).toInt()
          : int.tryParse('${m['user_role']}') ?? 0;
      // GET /users/{id} now resolves this server-side (`profileImageUrl`) —
      // use it directly, falling back to the bare `profileImage` path only
      // if an older backend didn't send it.
      final resolved = m['profileImageUrl'];
      _existingImage = (resolved is String && resolved.trim().isNotEmpty)
          ? resolved
          : profileImageUrl(m['profileImage']);
      _access = AccessSelection.fromJson(m['access']);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (x != null && mounted) setState(() => _pickedImage = x);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && _pickedImage == null) {
      setState(() => _error = 'Profile image is required for a new user.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(userRepositoryProvider).save(
            id: widget.userId,
            firstName: _first.text.trim(),
            lastName: _last.text.trim(),
            email: _email.text.trim(),
            // The Role field's own validator already blocked submission
            // while this was null.
            role: _role!,
            password: _pwd.text,
            imagePath: _pickedImage?.path,
            access: _access,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scroll) {
          if (_loading) return const LoadingView();
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Hs.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 10),
              // Web's `.modal-header{background:var(--primary-blue) /* #0052cc,
              // this page's own local accent */; color:white}`.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                color: const Color(0xFF0052CC),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit User' : 'Add User',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _field(_first, 'First Name',
                          validator: _required),
                      const SizedBox(height: 12),
                      _field(_last, 'Last Name', validator: _required),
                      const SizedBox(height: 12),
                      _field(_email, 'Email (Optional)',
                          keyboard: TextInputType.emailAddress,
                          hint: 'name@example.com', validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null;
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+').hasMatch(t);
                        return ok ? null : 'Enter a valid email';
                      }),
                      const SizedBox(height: 12),
                      _field(_pwd, 'Password',
                          obscure: true,
                          helper: _isEdit
                              ? 'Leave blank to keep current'
                              : 'Minimum 4 characters', validator: (v) {
                        if (_isEdit && (v ?? '').isEmpty) return null;
                        if ((v ?? '').length < 4) return 'Minimum 4 characters';
                        return null;
                      }),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _role,
                        decoration: const InputDecoration(
                            labelText: 'Role', hintText: 'Select Role'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('User')),
                          DropdownMenuItem(value: 1, child: Text('Admin')),
                        ],
                        validator: (v) => v == null ? 'Please select a role' : null,
                        onChanged: (v) => setState(() => _role = v),
                      ),
                      const SizedBox(height: 16),
                      const Text('Profile Image',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      _imagePreview(),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.photo_library_outlined, size: 18),
                        label: Text(_pickedImage == null
                            ? 'Choose Image'
                            : 'Change Image'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _isEdit
                              ? 'JPG, PNG, WEBP or GIF, max 5 MB.'
                              : 'JPG, PNG, WEBP or GIF, max 5 MB. '
                                  'Profile image is required.',
                          style:
                              const TextStyle(fontSize: 12, color: Hs.muted),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_role == null)
                        const SizedBox.shrink()
                      else if (_role == 0)
                        AccessEditor(
                          key: ValueKey(_isEdit ? widget.userId : 'new'),
                          selection: _access,
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EC),
                            borderRadius: BorderRadius.circular(Hs.radiusSm),
                            border: Border.all(color: const Color(0xFFCFE6D3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified_user_outlined,
                                  size: 18, color: Hs.green),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Admin has access to all modules, fields and locations.',
                                  style: TextStyle(
                                      color: Hs.green,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!,
                            style: const TextStyle(color: Hs.red)),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Save User'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Widget _field(
    TextEditingController c,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    bool obscure = false,
    String? helper,
    String? hint,
  }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboard,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
          labelText: label, helperText: helper, hintText: hint),
    );
  }

  Widget _imagePreview() {
    final size = 84.0;
    Widget inner;
    if (_pickedImage != null) {
      inner = Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
    } else if (_existingImage != null) {
      inner = Image.network(_existingImage!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person, color: Hs.faint));
    } else {
      inner = const Icon(Icons.person, size: 36, color: Hs.faint);
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Hs.hairline,
        shape: BoxShape.circle,
        border: Border.all(color: Hs.border),
      ),
      child: Center(child: inner),
    );
  }
}
