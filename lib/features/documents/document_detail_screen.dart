// lib/features/documents/document_detail_screen.dart
//
// One document's data from GET /documentdownload/detail. The API returns one
// row per line item with the header columns repeated on every row, and the
// columns differ per document type — so, generically: columns that hold the
// same value on every row are shown once as the document details, and the
// rest form the line-item table (a single-row document is all details).
// A summary card on top picks the party / date / amount out of those
// columns by their usual names, when the type has them.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/states.dart';
import 'document_format.dart';
import 'document_pdf.dart';
import 'document_repository.dart';

typedef _Key = ({int loc, String type, String key});

final _detailProvider =
    FutureProvider.family<List<Map<String, dynamic>>, _Key>((ref, k) {
  return ref.watch(documentRepositoryProvider).detail(
        locationId: k.loc,
        docType: k.type,
        key: k.key,
      );
});

/// Column names the summary card looks for, in priority order.
const _partyKeys = ['PartyName', 'AccName', 'TCustName', 'CustName'];
const _amountKeys = ['NetAmt', 'Amount', 'CAmount', 'BillAmt'];

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.locationId,
    required this.docType,
    required this.docKey,
  });
  final int locationId;
  final String docType;
  final String docKey;

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  final _hScroll = LinkedScrollControllerGroup();
  bool _downloading = false;

  String get _typeLabel {
    for (final t in ref.read(documentTypesProvider).valueOrNull ??
        const <DocTypeOption>[]) {
      if (t.key == widget.docType) return t.label;
    }
    return prettifyDocLabel(widget.docType);
  }

  DocLocation? get _location {
    for (final l in ref.read(documentLocationsProvider).valueOrNull ??
        const <DocLocation>[]) {
      if (l.id == widget.locationId) return l;
    }
    return null;
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    await downloadDocumentPdf(
      context,
      ref,
      locationId: widget.locationId,
      docType: widget.docType,
      docKey: widget.docKey,
      label: _typeLabel,
    );
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      loc: widget.locationId,
      type: widget.docType,
      key: widget.docKey,
    );
    final async = ref.watch(_detailProvider(key));
    // Watched so the type label / location name fill in once loaded.
    ref.watch(documentTypesProvider);
    ref.watch(documentLocationsProvider);

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'Document Detail',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf, color: Hs.red),
            onPressed: _downloading ? null : _download,
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(_detailProvider(key)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const EmptyView(message: 'Document not found.');
          }
          final first = rows.first;
          final cols = first.keys.toList();
          final details = <String>[];
          final lines = <String>[];
          for (final c in cols) {
            final v = '${first[c] ?? ''}';
            final same = rows.every((r) => '${r[c] ?? ''}' == v);
            (rows.length == 1 || same ? details : lines).add(c);
          }
          // Skip detail columns that are simply empty.
          final shown = [
            for (final c in details)
              if ('${first[c] ?? ''}'.trim().isNotEmpty) c,
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _summaryCard(first, cols, lines.isEmpty ? 0 : rows.length),
              if (shown.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(Icons.description_outlined, 'Document details'),
                const SizedBox(height: 8),
                _detailsTable(first, shown),
              ],
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionTitle(Icons.list_alt_outlined, 'Items',
                    count: rows.length),
                const SizedBox(height: 8),
                _itemsTable(rows, lines),
              ],
            ],
          );
        },
      ),
    );
  }

  // ---- summary ----------------------------------------------------------

  /// First of [candidates] present in the row with a non-empty value.
  String? _pick(Map<String, dynamic> row, List<String> candidates) {
    for (final k in candidates) {
      if ('${row[k] ?? ''}'.trim().isNotEmpty) return k;
    }
    return null;
  }

  Widget _summaryCard(Map<String, dynamic> row, List<String> cols, int items) {
    final partyKey = _pick(row, _partyKeys);
    final amountKey = _pick(row, _amountKeys);
    String? dateKey;
    for (final c in cols) {
      if (isDocDateColumn(c) && '${row[c] ?? ''}'.trim().isNotEmpty) {
        dateKey = c;
        break;
      }
    }
    final loc = _location;
    final locColor = parseHexColor(loc?.colorHex);

    return Container(
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radius),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: locColor ?? Hs.blue),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            // Web `.doc-type-badge`: #E3F2FD bg / #0052CC text.
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(_typeLabel,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0052CC))),
                        ),
                        const Spacer(),
                        if (loc != null) ...[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                                color: locColor ?? Hs.border,
                                shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(loc.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Hs.muted)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('DOC NO',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Hs.faint,
                            letterSpacing: .3)),
                    Text(widget.docKey,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Hs.ink)),
                    if (partyKey != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: Hs.muted),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                                formatDocCell(partyKey, row[partyKey]),
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Hs.inkSoft)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (dateKey != null)
                          Expanded(
                              child: _stat('Date',
                                  formatDocCell(dateKey, row[dateKey]))),
                        if (dateKey != null && amountKey != null)
                          const SizedBox(width: 8),
                        if (amountKey != null)
                          Expanded(
                            child: _stat('Amount',
                                '₹${formatDocCell(amountKey, row[amountKey])}',
                                color: Hs.green),
                          ),
                        if (items > 0) ...[
                          const SizedBox(width: 8),
                          Expanded(child: _stat('Items', '$items')),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _downloading ? null : _download,
                        icon: _downloading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.download, size: 18),
                        label:
                            Text(_downloading ? 'Preparing…' : 'Download PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, {Color color = Hs.ink}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Hs.hairline,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Hs.muted,
                  letterSpacing: .3)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }

  // ---- sections ---------------------------------------------------------

  Widget _sectionTitle(IconData icon, String text, {int? count}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Hs.blue),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Hs.ink)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Hs.blue.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Hs.blue)),
          ),
        ],
      ],
    );
  }

  /// The document-level fields as a bordered Field | Value table with
  /// alternating row shading.
  Widget _detailsTable(Map<String, dynamic> row, List<String> keys) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(3),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: Hs.hairline),
          verticalInside: BorderSide(color: Hs.hairline),
        ),
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF8F9FA)),
            children: [_headCell('Field'), _headCell('Value')],
          ),
          for (var i = 0; i < keys.length; i++)
            TableRow(
              decoration: BoxDecoration(
                  color: i.isOdd ? const Color(0xFFFBFBFD) : Hs.surface),
              children: [
                _labelCell(prettifyDocLabel(keys[i])),
                _valueCell(formatDocCell(keys[i], row[keys[i]]),
                    bold: isDocAmountColumn(keys[i])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _headCell(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: Hs.ink)),
      );

  Widget _labelCell(String t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Hs.muted)),
      );

  Widget _valueCell(String t, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: Hs.ink)),
      );

  /// Line items: pinned #, the varying columns scrolling sideways together.
  Widget _itemsTable(List<Map<String, dynamic>> rows, List<String> lines) {
    final columns = _lineColumns(lines);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          HsTableHeader(
            columns: columns,
            group: _hScroll,
            leadingWidth: 36,
            leadingLabel: '#',
          ),
          for (var i = 0; i < rows.length; i++)
            HsTableRow(
              columns: columns,
              group: _hScroll,
              striped: i.isOdd,
              leadingWidth: 36,
              leading: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${i + 1}',
                    style:
                        const TextStyle(fontSize: 12.5, color: Hs.inkSoft)),
              ),
              cells: [
                for (final c in lines)
                  Text(formatDocCell(c, rows[i][c]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isDocAmountColumn(c)
                          ? const TextStyle(fontWeight: FontWeight.w600)
                          : null),
              ],
            ),
        ],
      ),
    );
  }

  List<HsTableColumn> _lineColumns(List<String> keys) => [
        for (final k in keys)
          HsTableColumn(prettifyDocLabel(k),
              width: docColumnWidth(k), alignEnd: isDocAmountColumn(k)),
      ];
}
