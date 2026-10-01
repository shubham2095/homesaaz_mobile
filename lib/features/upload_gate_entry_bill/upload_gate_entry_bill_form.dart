// lib/features/upload_gate_entry_bill/upload_gate_entry_bill_form.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/states.dart';
import 'upload_gate_entry_bill_repository.dart';

/// Opens the add / edit sheet. Returns `true` if a change was saved.
Future<bool?> showUploadGateEntryBillForm(BuildContext context, {int? id}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BillForm(id: id),
  );
}

class _BillForm extends ConsumerStatefulWidget {
  const _BillForm({this.id});
  final int? id;

  @override
  ConsumerState<_BillForm> createState() => _BillFormState();
}

class _BillFormState extends ConsumerState<_BillForm> {
  final _picker = ImagePicker();
  XFile? _picked;
  String? _existingImage;
  String? _invoiceNumber;

  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m =
          await ref.read(uploadGateEntryBillRepositoryProvider).getOne(widget.id!);
      _invoiceNumber = '${m['InvoiceNumber'] ?? ''}';
      _existingImage = resolveAssetUrl(m['ImagePath']);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (x != null && mounted) setState(() => _picked = x);
  }

  Future<void> _save() async {
    if (!_isEdit && _picked == null) {
      setState(() => _error = 'Invoice image is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(uploadGateEntryBillRepositoryProvider).save(
            id: widget.id,
            imagePath: _picked?.path,
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
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (context, scroll) {
          if (_loading) return const LoadingView();
          return Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Hs.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text(_isEdit ? 'Edit Invoice' : 'Add Upload Gate Entry Bill',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    const Text('Invoice Number',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                      decoration: BoxDecoration(
                        color: Hs.hairline,
                        borderRadius: BorderRadius.circular(Hs.radiusSm),
                        border: Border.all(color: Hs.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long_outlined,
                              size: 18, color: Hs.muted),
                          const SizedBox(width: 8),
                          Text(
                            _invoiceNumber ?? 'Auto-generated on save',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _invoiceNumber != null
                                  ? Hs.ink
                                  : Hs.faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Invoice number will be generated automatically in series (INV-001, INV-002…)',
                        style: TextStyle(fontSize: 11.5, color: Hs.muted),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Invoice Image *',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pick(ImageSource.gallery),
                            icon: const Icon(Icons.folder_open_outlined,
                                size: 18),
                            label: const Text('Select File'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pick(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 18),
                            label: const Text('Take Photo'),
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text('JPG, PNG, GIF up to 5MB',
                          style: TextStyle(fontSize: 11.5, color: Hs.muted)),
                    ),
                    if (_picked != null) ...[
                      const SizedBox(height: 14),
                      const Text('New Image:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      _thumbnail(),
                    ] else if (_isEdit && _existingImage != null) ...[
                      const SizedBox(height: 14),
                      const Text('Current Image:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      _thumbnail(),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: const TextStyle(color: Hs.red)),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _saving ? null : () => Navigator.pop(context),
                            child: const Text('Cancel'),
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
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Small preview: the just-picked file, or the saved image on edit.
  Widget _thumbnail() {
    Widget inner;
    if (_picked != null) {
      inner = Image.file(File(_picked!.path), fit: BoxFit.cover);
    } else if (_existingImage != null) {
      inner = CachedNetworkImage(
        imageUrl: _existingImage!,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) =>
            const Icon(Icons.image_outlined, color: Hs.faint),
      );
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      height: 110,
      width: 110,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Hs.hairline,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(color: Hs.border),
      ),
      child: inner,
    );
  }
}
