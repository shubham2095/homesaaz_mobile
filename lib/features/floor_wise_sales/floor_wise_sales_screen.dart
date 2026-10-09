// lib/features/floor_wise_sales/floor_wise_sales_screen.dart
//
// Mirrors web `floorWiseSales/list.blade.php`: Location + From/To date
// filters (location required, like Gate Entry's heavy query), a compact
// "{Location} | dd-mm-yyyy" summary top-right, 4 summary cards, then the
// floor-wise table with a Share bar and a TOTAL row.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/states.dart';
import 'floor_wise_sales_repository.dart';

const _columns = <HsTableColumn>[
  // Floor (pinned) | Net Amount | Discount | Add. Disc. | Tax | Share | Gross
  // Amt — Gross sits last so the main figures show first. (The "Gross (40%+
  // Disc)" column was dropped on request; the Gross Amount summary card
  // above still includes it, matching the web.)
  HsTableColumn('Net Amount', width: 105, alignEnd: true),
  HsTableColumn('Discount', width: 95, alignEnd: true),
  HsTableColumn('Add. Disc.', width: 95, alignEnd: true),
  HsTableColumn('Tax', width: 85, alignEnd: true),
  HsTableColumn('Share', width: 90, alignEnd: true),
  HsTableColumn('Gross Amt', width: 95, alignEnd: true),
];

final _apiFmt = DateFormat('yyyy-MM-dd');
final _uiFmt = DateFormat('dd MMM yyyy');
final _headerDateFmt = DateFormat('dd-MM-yyyy');
final _dec2 = NumberFormat('#,##0.00', 'en_IN');

class FloorWiseSalesScreen extends ConsumerStatefulWidget {
  const FloorWiseSalesScreen({super.key});
  @override
  ConsumerState<FloorWiseSalesScreen> createState() =>
      _FloorWiseSalesScreenState();
}

class _FloorWiseSalesScreenState extends ConsumerState<FloorWiseSalesScreen> {
  int? _locationId;
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  int? _appliedLocationId;
  DateTime? _appliedFrom;
  DateTime? _appliedTo;

  final _hScroll = LinkedScrollControllerGroup();
  Future<FloorWiseSalesResult>? _future;

  void _apply() {
    setState(() {
      _appliedLocationId = _locationId;
      _appliedFrom = _fromDate;
      _appliedTo = _toDate;
      _future = ref.read(floorWiseSalesRepositoryProvider).load(
            locationId: _appliedLocationId!,
            dateFrom: _apiFmt.format(_appliedFrom!),
            dateTo: _apiFmt.format(_appliedTo!),
          );
    });
  }

  void _reset() {
    setState(() {
      _locationId = null;
      _fromDate = DateTime.now();
      _toDate = DateTime.now();
      _appliedLocationId = null;
      _appliedFrom = null;
      _appliedTo = null;
      _future = null;
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(now.year - 10),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(floorWiseSalesLocationsProvider);
    final canQuery = _appliedLocationId != null;

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Floor Wise Sales'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                canQuery
                    ? '${_locationName(locations, _appliedLocationId!)} | ${_headerDateFmt.format(_appliedTo!)}'
                    : _headerDateFmt.format(DateTime.now()),
                style: const TextStyle(
                    fontSize: 12, color: Hs.muted, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          _filterPanel(locations),
          Expanded(
            child: !canQuery
                ? const EmptyView(
                    message: 'Please select a Location (and dates) to load '
                        'Floor Wise Sales.')
                : FutureBuilder<FloorWiseSalesResult>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const LoadingView();
                      }
                      if (snap.hasError) {
                        return ErrorView(
                            message: '${snap.error}', onRetry: _apply);
                      }
                      return _content(snap.data!);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _locationName(
      AsyncValue<List<FloorWiseSalesLocation>> locations, int id) {
    for (final l in locations.valueOrNull ?? const <FloorWiseSalesLocation>[]) {
      if (l.id == id) return l.name;
    }
    return 'Location $id';
  }

  Widget _content(FloorWiseSalesResult r) {
    final t = r.totals;
    return RefreshIndicator(
      onRefresh: () async {
        _apply();
        await _future;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(children: [
            Expanded(
                child: _card('Net Sales', t['NetAmt'] ?? 0, Hs.blue,
                    highlighted: true)),
            const SizedBox(width: 10),
            // Web's Gross Amount card is GrossAmt + GrossAmt1 (the 40%+
            // discount rows have their own gross column in the table, but
            // count as plain gross here) — same for Discount below.
            Expanded(
                child: _card('Gross Amount',
                    (t['GrossAmt'] ?? 0) + (t['GrossAmt1'] ?? 0), Hs.muted)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _card('Discount',
                    (t['DisAmount'] ?? 0) + (t['AddDiscAmt'] ?? 0), Hs.muted)),
            const SizedBox(width: 10),
            Expanded(child: _card('Tax', t['TaxAmt'] ?? 0, Hs.muted)),
          ]),
          const SizedBox(height: 14),
          if (r.rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: Text('No sales for this location/date range.',
                      style: TextStyle(color: Hs.muted))),
            )
          else
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
                      leadingWidth: 100,
                      leadingLabel: 'Floor',
                    ),
                    for (final row in r.rows) _row(row, t['NetAmt'] ?? 0),
                    _totalRow(t, r.rows.length),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(String label, num value, Color accent, {bool highlighted = false}) {
    // Accent bar is its own child: a non-uniform Border can't be combined
    // with a borderRadius.
    return Container(
      decoration: BoxDecoration(
        color: Hs.surface,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
        border: Border.all(
            color: highlighted ? accent : Hs.border, width: highlighted ? 1.4 : 1),
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
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                      child: Text('₹${_dec2.format(value)}',
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

  /// Zero is greyed out, negative is red, matching the web table.
  Widget _amt(num v, {bool bold = false}) {
    return Text(
      _dec2.format(v),
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        color: v < 0 ? Hs.brandRed : (v == 0 ? Hs.faint : Hs.ink),
      ),
    );
  }

  Widget _row(FloorRow row, num netTotal) {
    final share = netTotal == 0 ? 0.0 : (row.values['NetAmt']! / netTotal * 100);
    return HsTableRow(
      columns: _columns,
      group: _hScroll,
      leadingWidth: 100,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(row.floorName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(fontWeight: FontWeight.w700, color: Hs.ink, fontSize: 13)),
      ),
      cells: [
        _amt(row.values['NetAmt']!, bold: true),
        _amt(row.values['DisAmount']!),
        _amt(row.values['AddDiscAmt']!),
        _amt(row.values['TaxAmt']!),
        _shareCell(share),
        _amt(row.values['GrossAmt']!),
      ],
    );
  }

  Widget _shareCell(double pct) {
    final clamped = pct.clamp(0, 100).toDouble();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 32,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: clamped / 100,
              minHeight: 5,
              backgroundColor: Hs.hairline,
              valueColor: const AlwaysStoppedAnimation(Hs.blue),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text('${pct.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 11.5, color: Hs.muted)),
      ],
    );
  }

  Widget _totalRow(Map<String, num> t, int count) {
    Widget b(num v) => Text(_dec2.format(v),
        style: TextStyle(
            fontWeight: FontWeight.w800,
            color: v < 0 ? Hs.brandRed : Hs.ink));
    return HsTableRow(
      columns: _columns,
      group: _hScroll,
      leadingWidth: 100,
      backgroundColor: const Color(0xFFEEF2F8),
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('TOTAL ($count)',
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Hs.ink, fontSize: 13)),
      ),
      cells: [
        b(t['NetAmt'] ?? 0),
        b(t['DisAmount'] ?? 0),
        b(t['AddDiscAmt'] ?? 0),
        b(t['TaxAmt'] ?? 0),
        const Text('100%',
            style: TextStyle(fontWeight: FontWeight.w800, color: Hs.ink, fontSize: 11.5)),
        b(t['GrossAmt'] ?? 0),
      ],
    );
  }

  Widget _filterPanel(AsyncValue<List<FloorWiseSalesLocation>> locations) {
    return HsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOCATION',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Hs.muted,
                  letterSpacing: .3)),
          const SizedBox(height: 6),
          locations.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('$e', style: const TextStyle(color: Hs.red)),
            data: (list) => Row(
              children: [
                Expanded(child: _locationPicker(list)),
                if (_locationId != null) ...[
                  const SizedBox(width: 8),
                  _colorChip(list),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _dateField('From Date', _fromDate,
                      () => _pickDate(isFrom: true))),
              const SizedBox(width: 10),
              Expanded(
                  child: _dateField(
                      'To Date', _toDate, () => _pickDate(isFrom: false))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _locationId == null ? null : _apply,
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

  Widget _colorChip(List<FloorWiseSalesLocation> list) {
    FloorWiseSalesLocation? loc;
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

  Widget _locationPicker(List<FloorWiseSalesLocation> list) {
    return DropdownButtonFormField<int>(
      initialValue: _locationId,
      isExpanded: true,
      decoration: const InputDecoration(hintText: '-- Select Location --'),
      items: [
        for (final l in list) DropdownMenuItem(value: l.id, child: Text(l.name)),
      ],
      onChanged: (v) => setState(() => _locationId = v),
    );
  }
}
