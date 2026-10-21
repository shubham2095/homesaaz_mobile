// lib/features/documents/document_list_screen.dart
//
// Mirrors web `documentDownload/list.blade.php` (v2): Location + Document
// Type + From/To date filters (all required — the data is read live from
// that location's own database), search, then a paginated table whose
// columns come from the chosen document type's query. Tapping a Doc No
// downloads its PDF (like the web); View opens the line-item detail.
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_footer_mixin.dart';
import '../../widgets/paged_list_view.dart';
import '../../widgets/states.dart';
import 'document_format.dart';
import 'document_pdf.dart';
import 'document_repository.dart';

final _apiFmt = DateFormat('yyyy-MM-dd');
final _uiFmt = DateFormat('dd MMM yyyy');

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});
  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen>
    with PagedFooterMixin<DocumentListScreen> {
  // Pending (what the dropdowns/pickers show) vs applied (what the query
  // uses) — set by "Apply Filter", same two-stage pattern as Gate Entry.
  int? _locationId;
  String? _docType;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  int? _appliedLocationId;
  String? _appliedDocType;
  DateTime? _appliedFrom;
  DateTime? _appliedTo;

  final _hScroll = LinkedScrollControllerGroup();

  // The web's "DOC NO" filter box — applied with the rest of the filters
  // (Apply Filter / the keyboard's Done key). The server matches it against
  // the document number (and the party name).
  final _docNoCtrl = TextEditingController();
  String _appliedDocNo = '';

  // Table columns of the applied doc type, from the first page's rows.
  List<String> _cols = const [];

  @override
  void dispose() {
    _docNoCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  bool get _canApply => _locationId != null && _docType != null;

  void _apply() {
    if (!_canApply) return;
    if (_to.isBefore(_from)) {
      _snack('To Date cannot be before From Date.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _appliedLocationId = _locationId;
      _appliedDocType = _docType;
      _appliedFrom = _from;
      _appliedTo = _to;
      _appliedDocNo = _docNoCtrl.text.trim();
      _cols = const [];
      resetFooter();
    });
  }

  void _reset() {
    _docNoCtrl.clear();
    final now = DateTime.now();
    setState(() {
      _locationId = null;
      _docType = null;
      _from = DateTime(now.year, now.month, 1);
      _to = now;
      _appliedLocationId = null;
      _appliedDocType = null;
      _appliedFrom = null;
      _appliedTo = null;
      _cols = const [];
      _appliedDocNo = '';
      resetFooter();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(now.year - 15),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => isFrom ? _from = picked : _to = picked);
    }
  }

  Future<PagedResponse<Map<String, dynamic>>> _fetch(int page, String _) {
    return ref.read(documentRepositoryProvider).list(
          page,
          _appliedDocNo,
          locationId: _appliedLocationId!,
          docType: _appliedDocType!,
          fromDate: _apiFmt.format(_appliedFrom!),
          toDate: _apiFmt.format(_appliedTo!),
        );
  }

  void _onPageLoaded(PageMeta meta, Map<String, dynamic> extra) {
    trackPage(meta, extra);
    final c = extra['columns'];
    if (c is List && c.isNotEmpty) {
      final cols = c.map((e) => '$e').toList();
      if (!listEquals(cols, _cols)) setState(() => _cols = cols);
    }
  }

  List<HsTableColumn> _tableColumns(List<String> keys) => [
        for (final k in keys)
          if (k != 'DocKey')
            HsTableColumn(prettifyDocLabel(k),
                width: docColumnWidth(k), alignEnd: isDocAmountColumn(k)),
        const HsTableColumn('Action', width: 80),
      ];

  String _docTypeLabel(String key) {
    for (final t in ref.read(documentTypesProvider).valueOrNull ??
        const <DocTypeOption>[]) {
      if (t.key == key) return t.label;
    }
    return prettifyDocLabel(key);
  }

  void _openDetail(String docKey) {
    context.push(Uri(path: '/documents/view', queryParameters: {
      'loc': '$_appliedLocationId',
      'type': _appliedDocType!,
      'key': docKey,
    }).toString());
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(documentLocationsProvider);
    final types = ref.watch(documentTypesProvider);
    final canQuery = _appliedLocationId != null && _appliedDocType != null;
    final signature =
        '$_appliedLocationId|$_appliedDocType|$_appliedFrom|$_appliedTo';

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Document Download'),
      body: !canQuery
          // Scrollable: with the Doc No box in the panel, the keyboard
          // shrinks this area, and a fixed Column overflowed by a few pixels.
          ? ListView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                _filterPanel(locations, types),
                const SizedBox(
                  height: 260,
                  child: EmptyView(
                      message: 'Please select Location and Document Type '
                          'to load documents.'),
                ),
              ],
            )
          : Column(
              children: [
                Expanded(
                  child: PagedListView<Map<String, dynamic>>(
                    key: ValueKey('$signature|$_appliedDocNo'),
                    searchable: false,
                    padding: EdgeInsets.zero,
                    separator: const SizedBox.shrink(),
                    emptyMessage: 'No documents found for this filter.',
                    fetchPage: _fetch,
                    onPageLoaded: _onPageLoaded,
                    header: Column(
                      children: [
                        _filterPanel(locations, types),
                        if (_cols.isNotEmpty)
                          HsTableHeader(
                            columns: _tableColumns(_cols),
                            group: _hScroll,
                            leadingWidth: 110,
                            leadingLabel: 'Doc No',
                          ),
                      ],
                    ),
                    itemBuilder: (context, m) => _row(m),
                  ),
                ),
                if (footerTotal > 0) footerBar(),
              ],
            ),
    );
  }

  Widget _row(Map<String, dynamic> m) {
    final keys = m.keys.toList();
    final docKey = '${m['DocKey'] ?? ''}'.trim();
    return HsTableRow(
      columns: _tableColumns(keys),
      group: _hScroll,
      leadingWidth: 110,
      // Tapping anywhere on the row opens the detail, not just "View". (The
      // Doc No link inside still downloads the PDF, like the web.)
      onTap: docKey.isEmpty ? null : () => _openDetail(docKey),
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: InkWell(
          onTap: docKey.isEmpty
              ? null
              : () => downloadDocumentPdf(
                    context,
                    ref,
                    locationId: _appliedLocationId!,
                    docType: _appliedDocType!,
                    docKey: docKey,
                    label: _docTypeLabel(_appliedDocType!),
                  ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(orDash(docKey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Hs.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: TextDecoration.underline)),
          ),
        ),
      ),
      cells: [
        for (final k in keys)
          if (k != 'DocKey')
            Text(formatDocCell(k, m[k]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: k == 'PartyName'
                    ? const TextStyle(fontWeight: FontWeight.w600, color: Hs.ink)
                    : null),
        docKey.isEmpty
            ? const Text('-')
            : Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  height: 28,
                  child: OutlinedButton(
                    onPressed: () => _openDetail(docKey),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: const Text('View'),
                  ),
                ),
              ),
      ],
    );
  }

  /// Web's "DOC NO" box: part of the filter panel, applied with the rest.
  Widget _docNoField() {
    return TextField(
      controller: _docNoCtrl,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _apply(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter Doc No…',
        prefixIcon: const Icon(Icons.search, size: 20, color: Hs.muted),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 42, minHeight: 42),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _docNoCtrl,
          builder: (_, v, __) => v.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  splashRadius: 18,
                  onPressed: _docNoCtrl.clear,
                ),
        ),
      ),
    );
  }

  Widget _filterPanel(AsyncValue<List<DocLocation>> locations,
      AsyncValue<List<DocTypeOption>> types) {
    return HsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('LOCATION'),
          const SizedBox(height: 6),
          locations.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Hs.red)),
            data: (list) => Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _locationId,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(hintText: '-- Select Location --'),
                    items: [
                      for (final l in list)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => setState(() => _locationId = v),
                  ),
                ),
                if (_locationId != null) ...[
                  const SizedBox(width: 8),
                  _colorChip(list),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _label('DOCUMENT TYPE'),
          const SizedBox(height: 6),
          types.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Hs.red)),
            data: (list) => DropdownButtonFormField<String>(
              initialValue: _docType,
              isExpanded: true,
              decoration:
                  const InputDecoration(hintText: '-- Select Document Type --'),
              items: [
                for (final t in list)
                  DropdownMenuItem(value: t.key, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _docType = v),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _dateField(
                      'From Date', _from, () => _pickDate(isFrom: true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _dateField(
                      'To Date', _to, () => _pickDate(isFrom: false))),
            ],
          ),
          const SizedBox(height: 12),
          _label('DOC NO'),
          const SizedBox(height: 6),
          _docNoField(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _canApply ? _apply : null,
                  icon: const Icon(Icons.filter_alt_outlined, size: 18),
                  label: const Text('Apply Filter'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Hs.muted,
          letterSpacing: .3));

  Widget _colorChip(List<DocLocation> list) {
    DocLocation? loc;
    for (final l in list) {
      if (l.id == _locationId) {
        loc = l;
        break;
      }
    }
    final c = parseHexColor(loc?.colorHex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Hs.hairline,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: c ?? Hs.border, shape: BoxShape.circle),
      ),
    );
  }

  Widget _dateField(String label, DateTime value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(_uiFmt.format(value)),
      ),
    );
  }
}
