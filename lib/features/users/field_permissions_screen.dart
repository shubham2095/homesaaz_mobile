// lib/features/users/field_permissions_screen.dart
//
// Web parity: `Field Permissions` lives inline inside the Add/Edit User
// form itself (a "Select Tables" checkbox grid, an expanding panel per
// checked table with its own field checkboxes + "Clear <Table>", and a
// running "Selected Permissions" summary) — not a separate screen/sheet.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../widgets/hs_widgets.dart';
import 'user_repository.dart';

/// Embed inside a user form. Reports every change via [onChanged] as
/// `{table: [fields]}` (tables with zero fields selected are omitted).
class FieldPermissionsEditor extends ConsumerStatefulWidget {
  const FieldPermissionsEditor({
    super.key,
    required this.initial,
    required this.onChanged,
  });

  final Map<String, List<String>> initial;
  final ValueChanged<Map<String, List<String>>> onChanged;

  @override
  ConsumerState<FieldPermissionsEditor> createState() =>
      _FieldPermissionsEditorState();
}

class _FieldPermissionsEditorState
    extends ConsumerState<FieldPermissionsEditor> {
  bool _loadingTables = true;
  String? _tablesError;
  List<String> _tables = [];

  final Map<String, List<String>> _fieldsCache = {};
  final Map<String, String> _fieldsError = {};
  final Set<String> _loadingFieldsFor = {};

  late final Set<String> _checked = {
    for (final e in widget.initial.entries)
      if (e.value.isNotEmpty) e.key,
  };
  late final Map<String, Set<String>> _selected = {
    for (final e in widget.initial.entries)
      if (e.value.isNotEmpty) e.key: e.value.toSet(),
  };

  @override
  void initState() {
    super.initState();
    _loadTables();
    for (final t in _checked) {
      _ensureFieldsLoaded(t);
    }
  }

  Future<void> _loadTables() async {
    setState(() {
      _loadingTables = true;
      _tablesError = null;
    });
    try {
      final t = await ref.read(userRepositoryProvider).permissionTables();
      if (mounted) setState(() => _tables = t);
    } catch (e) {
      if (mounted) setState(() => _tablesError = '$e');
    } finally {
      if (mounted) setState(() => _loadingTables = false);
    }
  }

  Future<void> _ensureFieldsLoaded(String table) async {
    if (_fieldsCache.containsKey(table) || _loadingFieldsFor.contains(table)) {
      return;
    }
    setState(() {
      _loadingFieldsFor.add(table);
      _fieldsError.remove(table);
    });
    try {
      final f = await ref.read(userRepositoryProvider).tableFields(table);
      if (mounted) setState(() => _fieldsCache[table] = f);
    } catch (e) {
      if (mounted) setState(() => _fieldsError[table] = '$e');
    } finally {
      if (mounted) setState(() => _loadingFieldsFor.remove(table));
    }
  }

  void _emit() => widget.onChanged({
    for (final e in _selected.entries)
      if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
  });

  void _toggleTable(String table, bool checked) {
    setState(() {
      if (checked) {
        _checked.add(table);
      } else {
        _checked.remove(table);
        _selected.remove(table);
      }
    });
    if (checked) _ensureFieldsLoaded(table);
    _emit();
  }

  void _toggleAllTables(bool checkAll) {
    setState(() {
      if (checkAll) {
        _checked
          ..clear()
          ..addAll(_tables);
      } else {
        _checked.clear();
        _selected.clear();
      }
    });
    if (checkAll) {
      for (final t in _tables) {
        _ensureFieldsLoaded(t);
      }
    }
    _emit();
  }

  void _toggleField(String table, String field, bool checked) {
    setState(() {
      final set = _selected.putIfAbsent(table, () => <String>{});
      if (checked) {
        set.add(field);
      } else {
        set.remove(field);
        if (set.isEmpty) _selected.remove(table);
      }
    });
    _emit();
  }

  void _toggleAllFields(String table, bool checkAll) {
    final fields = _fieldsCache[table] ?? const [];
    setState(() {
      if (checkAll) {
        _selected[table] = fields.toSet();
      } else {
        _selected.remove(table);
      }
    });
    _emit();
  }

  void _clearTable(String table) {
    setState(() => _selected.remove(table));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final sortedChecked = _checked.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Field Permissions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Hs.ink),
        ),
        const SizedBox(height: 2),
        const Text(
          'Select a table and choose which fields this user can view.',
          style: TextStyle(fontSize: 12, color: Hs.muted),
        ),
        const SizedBox(height: 12),
        const Text(
          'Select Tables',
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Hs.ink),
        ),
        const SizedBox(height: 6),
        _tablesBox(),
        for (final t in sortedChecked) _tablePanel(t),
        const SizedBox(height: 10),
        _selectedSummary(),
      ],
    );
  }

  Widget _tablesBox() {
    return Container(
      decoration: BoxDecoration(
        color: Hs.hairline,
        border: Border.all(color: Hs.border),
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          CheckboxListTile(
            value: _tables.isNotEmpty && _tables.every(_checked.contains),
            onChanged: _loadingTables ? null : (v) => _toggleAllTables(v ?? false),
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Select All Tables',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 240,
            child: _loadingTables
                ? const Center(
                    child: SizedBox(
                        width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
                : _tablesError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_tablesError!,
                                  style: const TextStyle(color: Hs.red, fontSize: 12),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 6),
                              TextButton(onPressed: _loadTables, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: _checkGrid(2, [
                            for (final t in _tables)
                              _CheckItem(t, _checked.contains(t),
                                  (v) => _toggleTable(t, v ?? false)),
                          ]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _tablePanel(String table) {
    final loading = _loadingFieldsFor.contains(table);
    final error = _fieldsError[table];
    final fields = _fieldsCache[table];
    final selected = _selected[table] ?? const <String>{};
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Hs.border),
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Hs.hairline,
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(table,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                ),
                if (fields != null && fields.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: fields.every(selected.contains),
                        onChanged: (v) => _toggleAllFields(table, v ?? false),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Text('Select All Fields', style: TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                        child: SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : error != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(error,
                              style: const TextStyle(color: Hs.red, fontSize: 12)),
                          TextButton(
                            onPressed: () => _ensureFieldsLoaded(table),
                            child: const Text('Retry'),
                          ),
                        ],
                      )
                    : (fields == null || fields.isEmpty)
                        ? const Text('No fields found for this table.',
                            style: TextStyle(color: Hs.muted, fontSize: 12.5))
                        : _checkGrid(2, [
                            for (final f in fields)
                              _CheckItem(f, selected.contains(f),
                                  (v) => _toggleField(table, f, v ?? false)),
                          ]),
          ),
          if (fields != null && fields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Hs.red,
                  side: const BorderSide(color: Hs.red),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: selected.isEmpty ? null : () => _clearTable(table),
                child: Text('Clear $table', style: const TextStyle(fontSize: 12.5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectedSummary() {
    final entries = _selected.entries.where((e) => e.value.isNotEmpty).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Hs.hairline,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(color: Hs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selected Permissions',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Hs.ink)),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            const Text('No field permissions selected.',
                style: TextStyle(color: Hs.muted, fontSize: 12.5))
          else
            for (final e in entries) _summaryCard(e.key, e.value),
        ],
      ),
    );
  }

  Widget _summaryCard(String table, Set<String> fields) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: const Border(left: BorderSide(color: Hs.blue, width: 3)),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(table, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              TextButton(
                onPressed: () => _clearTable(table),
                child: const Text('Remove', style: TextStyle(color: Hs.red)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final f in fields) HsPill(f, color: Hs.blue)],
          ),
        ],
      ),
    );
  }

  /// Builds a fixed-column checkbox grid. Cell width depends on the
  /// available width, which `LayoutBuilder` only knows at build time — so
  /// the items are described (not pre-built as widgets) and turned into
  /// correctly-sized `SizedBox`es *inside* the builder callback.
  Widget _checkGrid(int columns, List<_CheckItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / columns;
        return Wrap(
          children: [
            for (final it in items)
              SizedBox(
                width: width,
                child: CheckboxListTile(
                  value: it.value,
                  onChanged: it.onChanged,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
                  title: Text(
                    it.label,
                    style: const TextStyle(fontSize: 12.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CheckItem {
  const _CheckItem(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool?> onChanged;
}
