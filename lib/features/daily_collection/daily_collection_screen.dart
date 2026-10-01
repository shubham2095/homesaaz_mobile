// lib/features/daily_collection/daily_collection_screen.dart
//
// Mirrors the web Daily Collection page: 4 summary cards, location search,
// then the location-wise table with a TOTAL row.
//
// The backend's own search only matches the `Location` CODE column (e.g.
// "LJP"), but the table itself (like the web) shows that same code, not
// the full branch name — so searching by name silently returned nothing.
// Fixed by loading the full (small, unpaginated) list once and filtering
// locally against BOTH the code and `LocationName`, recomputing the
// summary cards + TOTAL row from whatever rows are currently visible —
// exactly what the backend's own search does server-side.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/states.dart';
import 'daily_collection_repository.dart';

const _columns = <HsTableColumn>[
  HsTableColumn('Location', width: 110),
  HsTableColumn('Cash', width: 110, alignEnd: true),
  HsTableColumn('Credit Card', width: 110, alignEnd: true),
  HsTableColumn('Cheque', width: 110, alignEnd: true),
  HsTableColumn('Total Amount', width: 120, alignEnd: true),
  HsTableColumn('Disc %', width: 80, alignEnd: true),
];

final _dec2 = NumberFormat('#,##0.00', 'en_IN');
const _totalBg = Color(0xFFEEF2F8);

class DailyCollectionScreen extends ConsumerStatefulWidget {
  const DailyCollectionScreen({super.key});
  @override
  ConsumerState<DailyCollectionScreen> createState() =>
      _DailyCollectionScreenState();
}

class _DailyCollectionScreenState
    extends ConsumerState<DailyCollectionScreen> {
  final _hScroll = LinkedScrollControllerGroup();
  final _searchCtrl = TextEditingController();
  String _search = '';
  late Future<DailyCollectionResult> _future = _fetch();

  // Always loads the full list — search is applied locally below, so a new
  // keystroke never needs a network round trip.
  Future<DailyCollectionResult> _fetch() =>
      ref.read(dailyCollectionRepositoryProvider).load();

  void _reload() => setState(() => _future = _fetch());

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) => setState(() => _search = v.trim());

  void _reset() {
    _searchCtrl.clear();
    setState(() => _search = '');
  }

  /// Matches the backend's own `Location` (code) match, plus the full
  /// `LocationName` — so searching "LJP" and "HOME SAAZ LJP" both work.
  List<Map<String, dynamic>> _filteredRows(List<Map<String, dynamic>> rows) {
    final q = _search.toLowerCase();
    if (q.isEmpty) return rows;
    return rows.where((r) {
      final code = '${r['Location'] ?? ''}'.toLowerCase();
      final name = '${r['LocationName'] ?? ''}'.toLowerCase();
      return code.contains(q) || name.contains(q);
    }).toList();
  }

  /// Cash/Credit Card/Cheque/Total for whichever rows are currently
  /// visible — the cards and TOTAL row track the search like the web's own
  /// server-side totals do.
  Map<String, num> _totalsFor(List<Map<String, dynamic>> rows) {
    num cash = 0, card = 0, cheque = 0, amount = 0;
    for (final r in rows) {
      cash += asNum(r['Cash']) ?? 0;
      card += asNum(r['CreditCard']) ?? 0;
      cheque += asNum(r['Cheque']) ?? 0;
      amount += asNum(r['TAmount']) ?? 0;
    }
    return {
      'Cash': cash,
      'CreditCard': card,
      'Cheque': cheque,
      'TAmount': amount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'Daily Collection',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<DailyCollectionResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: _reload);
          }
          return _content(snap.data!);
        },
      ),
    );
  }

  Widget _content(DailyCollectionResult r) {
    final rows = _filteredRows(r.rows);
    final t = _totalsFor(rows);
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          if (r.updatedAt.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Last updated: ${r.updatedAt}',
                  style: const TextStyle(fontSize: 12, color: Hs.muted)),
            ),
          Row(children: [
            Expanded(child: _card('Total Collection', t['TAmount'], Hs.blue)),
            const SizedBox(width: 10),
            Expanded(child: _card('Cash', t['Cash'], Hs.muted)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _card('Credit Card', t['CreditCard'], Hs.muted)),
            const SizedBox(width: 10),
            Expanded(child: _card('Cheque', t['Cheque'], Hs.muted)),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search location…',
                  prefixIcon: Icon(Icons.search, size: 20, color: Hs.muted),
                  prefixIconConstraints:
                      BoxConstraints(minWidth: 42, minHeight: 42),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _reset,
              // The theme's minimumSize is (infinity, 46) — inside a Row that
              // throws and the whole screen renders blank.
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
              icon: const Icon(Icons.highlight_off, size: 18),
              label: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(Hs.radiusSm),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Hs.surface,
                border: Border.all(color: Hs.border),
              ),
              child: Column(
                children: [
                  HsTableHeader(
                    columns: _columns,
                    group: _hScroll,
                    leadingWidth: 40,
                    leadingLabel: '#',
                  ),
                  if (rows.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                          _search.isEmpty
                              ? 'No records found.'
                              : 'No location matches "$_search".',
                          style: const TextStyle(color: Hs.muted)),
                    )
                  else ...[
                    for (final row in rows)
                      _row(row, parseHexColor('${row['LocationColor'] ?? ''}')),
                    _totalRow(t, rows.length),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(String label, Object? value, Color accent) {
    // Accent bar is its own child: a non-uniform Border can't be combined
    // with a borderRadius.
    return Container(
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(color: Hs.border),
        boxShadow: Hs.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Hs.muted,
                            letterSpacing: .3)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('₹${_dec2.format(asNum(value) ?? 0)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Hs.ink)),
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

  /// Zero amounts are greyed out, as on the web.
  Widget _amt(Object? v, {bool bold = false, bool pct = false}) {
    final n = asNum(v) ?? 0;
    final text = pct ? '${_dec2.format(n)}%' : _dec2.format(n);
    return Text(text,
        style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: n == 0 ? Hs.faint : (bold ? Hs.ink : Hs.inkSoft)));
  }

  Widget _row(Map<String, dynamic> m, Color? locationColor) {
    return HsTableRow(
      columns: _columns,
      group: _hScroll,
      leadingWidth: 40,
      // A soft tint of the branch's own colour (Locations page), same idea
      // as the Stock table's per-location row tint.
      backgroundColor: locationColor?.withValues(alpha: .07),
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('${m['SrNo'] ?? ''}',
              style: const TextStyle(fontSize: 13, color: Hs.inkSoft)),
        ),
      ),
      cells: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: locationColor ?? Hs.border,
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
              child: Text(orDash(m['Location']),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Hs.ink,
                      fontSize: 13)),
            ),
          ],
        ),
        _amt(m['Cash']),
        _amt(m['CreditCard']),
        _amt(m['Cheque']),
        _amt(m['TAmount'], bold: true),
        _amt(m['DiscPCT'], pct: true),
      ],
    );
  }

  Widget _totalRow(Map<String, dynamic> t, int count) {
    Widget b(Object? v) => Text(_dec2.format(asNum(v) ?? 0),
        style: const TextStyle(fontWeight: FontWeight.w800, color: Hs.ink));
    return HsTableRow(
      columns: _columns,
      group: _hScroll,
      leadingWidth: 40,
      backgroundColor: _totalBg,
      cells: [
        Text('TOTAL ($count)',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Hs.ink, fontSize: 13)),
        b(t['Cash']),
        b(t['CreditCard']),
        b(t['Cheque']),
        b(t['TAmount']),
        const Text('-',
            style: TextStyle(fontWeight: FontWeight.w800, color: Hs.ink)),
      ],
    );
  }
}
