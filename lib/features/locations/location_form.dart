// lib/features/locations/location_form.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../widgets/states.dart';
import 'location_repository.dart';

Color? locationHexToColor(String v) {
  final s = v.replaceAll('#', '').trim();
  if (s.length != 6) return null;
  final n = int.tryParse('FF$s', radix: 16);
  return n == null ? null : Color(n);
}

const _presetColors = <String>[
  '#DC3545', '#F59E0B', '#FFF200', '#22C55E', '#10B981',
  '#06B6D4', '#3B82F6', '#6366F1', '#A855F7', '#EC4899',
  '#F5C0C0', '#CBEBA6', '#B7E2F3', '#9CA3AF', '#111827',
];

/// Opens the add / edit sheet. Returns `true` if a change was saved.
Future<bool?> showLocationForm(BuildContext context, {int? locationId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _LocationForm(locationId: locationId),
  );
}

class _LocationForm extends ConsumerStatefulWidget {
  const _LocationForm({this.locationId});
  final int? locationId;

  @override
  ConsumerState<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends ConsumerState<_LocationForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _address = TextEditingController();
  final _gst = TextEditingController();
  final _color = TextEditingController();

  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.locationId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _address.dispose();
    _gst.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m =
          await ref.read(locationRepositoryProvider).getOne(widget.locationId!);
      _name.text = '${m['LocationName'] ?? ''}';
      _code.text = '${m['Locationcode'] ?? ''}';
      _address.text = '${m['LocationAddress'] ?? ''}';
      _gst.text = '${m['GST'] ?? ''}';
      final c = '${m['Color'] ?? ''}';
      _color.text = c.startsWith('#') ? c : (c.isEmpty ? '' : '#$c');
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(locationRepositoryProvider).save(
            id: widget.locationId,
            name: _name.text.trim(),
            code: _code.text.trim(),
            address: _address.text.trim(),
            gst: _gst.text.trim(),
            colorHex: _color.text.trim().isEmpty ? null : _color.text.trim(),
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
    final swatch = locationHexToColor(_color.text);
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
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 10),
              // Web's location modal has a solid `bg-primary text-white`
              // header bar (`.modal-header`) — reproduced here instead of
              // a plain white sheet header.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                color: Hs.blue,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Location' : 'Add Location',
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
                      TextFormField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Location Name *'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        enabled: !_isEdit,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Location Code *',
                          helperText: _isEdit
                              ? 'Code cannot be changed'
                              : 'Short unique code, e.g. LJP',
                        ),
                        validator: (v) {
                          if (_isEdit) return null;
                          return (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _address,
                        maxLines: 2,
                        decoration:
                            const InputDecoration(labelText: 'Location Address'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _gst,
                        textCapitalization: TextCapitalization.characters,
                        decoration:
                            const InputDecoration(labelText: 'GST Number'),
                      ),
                      const SizedBox(height: 18),
                      const Text('Color Badge',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: swatch ?? Hs.hairline,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Hs.border),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _color,
                              onChanged: (_) => setState(() {}),
                              inputFormatters: [
                                LengthLimitingTextInputFormatter(7),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Hex (#RRGGBB)',
                                hintText: '#DC3545',
                              ),
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return null;
                                return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(s)
                                    ? null
                                    : 'Use #RRGGBB';
                              },
                            ),
                          ),
                          if (_color.text.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close),
                              onPressed: () =>
                                  setState(() => _color.clear()),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final hex in _presetColors)
                            GestureDetector(
                              onTap: () => setState(() => _color.text = hex),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: locationHexToColor(hex),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _color.text.toUpperCase() ==
                                            hex.toUpperCase()
                                        ? Hs.ink
                                        : Hs.border,
                                    width: _color.text.toUpperCase() ==
                                            hex.toUpperCase()
                                        ? 2
                                        : 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(_error!, style: const TextStyle(color: Hs.red)),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => Navigator.pop(context),
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
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Text('Save Location'),
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
}
