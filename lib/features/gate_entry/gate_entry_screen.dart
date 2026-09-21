// lib/features/gate_entry/gate_entry_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'gate_entry_repository.dart';

/// Column order mirrors web `gateEntry/list.blade.php`'s `<thead>` — Floor
/// Name is the pinned leading column, the rest scroll horizontally.
const _columns = <HsTableColumn>[
  HsTableColumn('GRN Date', width: 100),
  HsTableColumn('GRN No', width: 80),
  HsTableColumn('Billing', width: 90),
  HsTableColumn('Supplier', width: 240),
  HsTableColumn('GRN Amount', width: 100, alignEnd: true),
  HsTableColumn('Bill Amount', width: 100, alignEnd: true),
  HsTableColumn('Total MRP', width: 100, alignEnd: true),
];

class GateEntryScreen extends ConsumerStatefulWidget {
  const GateEntryScreen({super.key});
  @override
  ConsumerState<GateEntryScreen> createState() => _GateEntryScreenState();
}

class _GateEntryScreenState extends ConsumerState<GateEntryScreen>
    with PagedFooterMixin<GateEntryScreen> {
  int? _locationId;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Only these drive the query — set by "Apply Filter".
  int? _appliedLocationId;
  DateTime? _appliedFrom;
  DateTime? _appliedTo;

  final _hScroll = LinkedScrollControllerGroup();
  final _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _debounce;

  static final _apiFmt = DateFormat('yyyy-MM-dd');
  static final _uiFmt = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() {
        _search = v.trim();
        resetFooter();
      });
    });
  }

  Future<PagedResponse<Map<String, dynamic>>> _fetch(
      int page, String search) {
    return ref.read(gateEntryRepositoryProvider).list(
          page,
          _search,
          locationId: _appliedLocationId,
          dateFrom: _appliedFrom == null ? null : _apiFmt.format(_appliedFrom!),
          dateTo: _appliedTo == null ? null : _apiFmt.format(_appliedTo!),
        );
  }

  void _apply() {
    setState(() {
      _appliedLocationId = _locationId;
      _appliedFrom = _fromDate;
      _appliedTo = _toDate;
      resetFooter();
    });
  }

  void _reset() {
    _searchCtrl.clear();
    setState(() {
      _locationId = null;
      _fromDate = null;
      _toDate = null;
      _appliedLocationId = null;
      _appliedFrom = null;
      _appliedTo = null;
      _search = '';
      resetFooter();
    });
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _fromDate : _toDate) ?? now,
      firstDate: DateTime(now.year - 15),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => isFrom ? _fromDate = picked : _toDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(gateEntryLocationsProvider);
    final canQuery = _appliedLocationId != null;
    final signature = '$_appliedLocationId|$_appliedFrom|$_appliedTo';

    // Web's own column-name auto-detection means the live server can be
    // serving this from either a direct-SQL fast path or a stored-procedure
    // fallback, which don't necessarily agree on exact casing — so every
    // field is looked up under every plausible alias the backend is known
    // to use (see GateEntry::getFastPaginatedData's own `$pick()` calls).
    Widget listBody() {
      return Column(
        children: [
          Expanded(
            child: PagedListView<Map<String, dynamic>>(
              key: ValueKey('$signature|$_search'),
              searchable: false,
              padding: EdgeInsets.zero,
              separator: const SizedBox.shrink(),
              fetchPage: _fetch,
              onPageLoaded: trackPage,
              header: Column(
          children: [
            _filterPanel(locations),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'GRN no, supplier, floor…',
                  prefixIcon: const Icon(Icons.search, size: 20, color: Hs.muted),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 42, minHeight: 42),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          splashRadius: 18,
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        ),
                ),
              ),
            ),
            HsTableHeader(
              columns: _columns,
              group: _hScroll,
              leadingWidth: 110,
              leadingLabel: 'Floor Name',
            ),
          ],
        ),
        itemBuilder: (context, m) => HsTableRow(
          columns: _columns,
          group: _hScroll,
          leadingWidth: 110,
          leading: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              orDash(_pick(m, const ['FloorName', 'Floor', 'FloorDescription'])),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Hs.ink, fontSize: 13),
            ),
          ),
          cells: [
            Text(prettyDate(
                _pick(m, const ['GrnDate', 'GRNDate', 'EntryDate', 'Date']))),
            Text(orDash(
                _pick(m, const ['GmNo', 'GRNNo', 'GrnNo', 'EntryNo', 'GMNo']))),
            Text(orDash(_pick(m, const ['Billing', 'BillNo', 'Billno']))),
            Text(orDash(
                _pick(m, const ['Supplier', 'SupplierName', 'AccName']))),
            Text(money(_pick(m, const [
              'GmAmount',
              'GrnAmount',
              'GRNAmount',
              'GmAmt',
              'Amount',
            ]))),
            Text(money(_pick(m, const ['BillAmount', 'BillAmt']))),
            Text(money(_pick(
                m, const ['TotMRP', 'TotalMRP', 'TotMrp', 'TotalMrp']))),
          ],
        ),
      ),
          ),
          if (footerTotal > 0) footerBar(),
        ],
      );
    }

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Gate Entry Details'),
      body: !canQuery
          ? Column(
              children: [
                _filterPanel(locations),
                const Expanded(
                  child: EmptyView(
                      message:
                          'Please select Location to load Gate Entry details.'),
                ),
              ],
            )
          : listBody(),
    );
  }

  /// Returns the first non-empty value found under any of [keys].
  static String? _pick(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v != null && '$v'.trim().isNotEmpty) return '$v';
    }
    return null;
  }

  Widget _filterPanel(AsyncValue<Map<int, GateEntryLocation>> locations) {
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
            data: (map) => Row(
              children: [
                Expanded(child: _locationPicker(map)),
                if (_locationId != null && map[_locationId] != null) ...[
                  const SizedBox(width: 8),
                  _colorChip(map[_locationId]!),
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

  Widget _colorChip(GateEntryLocation loc) {
    final c = parseGateEntryColor(loc.colorHex);
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

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value == null ? 'mm/dd/yyyy' : _uiFmt.format(value),
          style: TextStyle(color: value == null ? Hs.faint : Hs.ink),
        ),
      ),
    );
  }

  Widget _locationPicker(Map<int, GateEntryLocation> map) {
    final entries = map.entries.toList()
      ..sort((a, b) =>
          a.value.name.toLowerCase().compareTo(b.value.name.toLowerCase()));
    return DropdownButtonFormField<int>(
      initialValue: _locationId,
      isExpanded: true,
      decoration: const InputDecoration(hintText: '-- Select Location --'),
      items: [
        for (final e in entries)
          DropdownMenuItem(value: e.key, child: Text(e.value.name)),
      ],
      onChanged: (v) => setState(() => _locationId = v),
    );
  }
}
