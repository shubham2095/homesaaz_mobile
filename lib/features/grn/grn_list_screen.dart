// lib/features/grn/grn_list_screen.dart
import 'dart:async';

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
import 'grn_repository.dart';

/// Column order mirrors web `grn/list.blade.php`'s `<thead>` — Floor Name
/// is the pinned leading column, the rest scroll horizontally.
const _columns = <HsTableColumn>[
  HsTableColumn('GRN Date', width: 100),
  HsTableColumn('GRN No', width: 80),
  HsTableColumn('Detail', width: 70),
  HsTableColumn('Bill No.', width: 90),
  HsTableColumn('Supplier', width: 240),
  HsTableColumn('GRN Amount', width: 100, alignEnd: true),
  HsTableColumn('Bill Amount', width: 100, alignEnd: true),
  HsTableColumn('Total MRP', width: 100, alignEnd: true),
];

class GrnListScreen extends ConsumerStatefulWidget {
  const GrnListScreen({super.key});
  @override
  ConsumerState<GrnListScreen> createState() => _GrnListScreenState();
}

/// Different location stored procs expose the GRN number under different
/// column names — mirrors the fallback chain the web app uses
/// (grn/list.blade.php) so whichever one the backend actually populated
/// still shows up here instead of a dash.
String _grnNoLabel(Map<String, dynamic> m) => orDash(m['GmNo'] ??
    m['GRNNo'] ??
    m['GrnNo'] ??
    m['EntryNo'] ??
    m['GMNo'] ??
    m['GRNID']);

class _GrnListScreenState extends ConsumerState<GrnListScreen>
    with PagedFooterMixin<GrnListScreen> {
  int? _locationId;
  DateTime? _fromDate;
  DateTime? _toDate;

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
    return ref.read(grnRepositoryProvider).list(
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
    final locations = ref.watch(grnLocationsProvider);
    final canQuery = _appliedLocationId != null;
    final signature = '$_appliedLocationId|$_appliedFrom|$_appliedTo';

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
        itemBuilder: (context, m) {
          final id = asInt(m['GRNID']);
          return HsTableRow(
            columns: _columns,
            group: _hScroll,
            leadingWidth: 110,
            onTap: id == null
                ? null
                : () => context.push(
                      '/grn/$id?loc=$_appliedLocationId',
                      extra: m,
                    ),
            leading: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                orDash(m['FloorName']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Hs.ink, fontSize: 13),
              ),
            ),
            cells: [
              Text(prettyDate(m['GrnDate'])),
              Text(_grnNoLabel(m)),
              id == null
                  ? const Text('-')
                  : const Text('Details',
                      style: TextStyle(
                          color: Hs.blue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
              Text(orDash(m['Billno'] ?? m['Billing'])),
              Text(orDash(m['Supplier'])),
              Text(money(m['GrnAmount'] ?? m['GmAmount'])),
              Text(money(m['BillAmount'])),
              Text(money(m['TotMRP'] ?? m['TotalMrp'] ?? m['TotalMRP'])),
            ],
          );
        },
      ),
          ),
          if (footerTotal > 0) _totalEntriesBar(),
          if (footerTotal > 0) footerBar(),
        ],
      );
    }

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'GRN Details'),
      body: !canQuery
          ? Column(
              children: [
                _filterPanel(locations),
                const Expanded(
                  child: EmptyView(
                      message: 'Please select Location to load GRN details.'),
                ),
              ],
            )
          : listBody(),
    );
  }

  /// Web's "Total Entries: N" bar, shown above the "Showing…" footer.
  Widget _totalEntriesBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Hs.surface,
        border: Border(top: BorderSide(color: Hs.border)),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13, color: Hs.ink),
          children: [
            const TextSpan(text: 'Total Entries: '),
            TextSpan(
              text: '$footerTotal',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Hs.blue),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPanel(AsyncValue<Map<int, GrnLocation>> locations) {
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

  Widget _colorChip(GrnLocation loc) {
    final c = parseGrnColor(loc.colorHex);
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

  Widget _locationPicker(Map<int, GrnLocation> map) {
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
