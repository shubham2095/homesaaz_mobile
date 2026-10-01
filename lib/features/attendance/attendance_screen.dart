// lib/features/attendance/attendance_screen.dart
//
// Mirrors web `attendance/list.blade.php`: "Today: dd-mm-yyyy" at the top,
// a Location + Attendance(status) + Search filter panel with Apply
// Filter/Reset, 4 summary cards (the one matching the applied status is
// outlined), then the list. Loads immediately with no location required —
// unlike Gate Entry's heavy stored procedure, this reads a plain table.
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
import '../../widgets/phone_link.dart';
import 'attendance_repository.dart';

// Column widths give full names/numbers room to render without ellipsis —
// the table scrolls sideways as a whole (see hs_table.dart), so a wider
// column here just means a bit more horizontal scroll, not wasted space.
const _columns = <HsTableColumn>[
  HsTableColumn('Code', width: 70),
  HsTableColumn('Employee', width: 200),
  HsTableColumn('Mobile', width: 150),
  HsTableColumn('Location', width: 170),
  HsTableColumn('Today', width: 80, alignEnd: true),
  HsTableColumn('Present', width: 70, alignEnd: true),
  HsTableColumn('Absent', width: 70, alignEnd: true),
  HsTableColumn('Late', width: 60, alignEnd: true),
  HsTableColumn('Half Day', width: 80, alignEnd: true),
];

const _todayOptions = <(String value, String label)>[
  ('present', 'Present'),
  ('absent', 'Absent'),
  ('late', 'Late'),
  ('all', 'All'),
];

final _todayDateFmt = DateFormat('dd-MM-yyyy');

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen>
    with PagedFooterMixin<AttendanceScreen> {
  // Pending (edited by the dropdowns/search box) vs applied (drives the
  // query) — same two-stage pattern as Gate Entry's filter panel.
  int? _locationId;
  String _today = 'present';
  int? _appliedLocationId;
  String _appliedToday = 'present';

  final _hScroll = LinkedScrollControllerGroup();
  final _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _debounce;
  AttendanceSummary _summary = const AttendanceSummary();

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

  void _apply() {
    setState(() {
      _appliedLocationId = _locationId;
      _appliedToday = _today;
      resetFooter();
    });
  }

  void _reset() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _locationId = null;
      _today = 'present';
      _appliedLocationId = null;
      _appliedToday = 'present';
      _search = '';
      resetFooter();
    });
  }

  /// Tapping a summary card jumps straight to that status, like tapping its
  /// matching dropdown option + Apply Filter.
  void _applyStatus(String status) {
    setState(() {
      _today = status;
      _appliedToday = status;
      resetFooter();
    });
  }

  Future<PagedResponse<Map<String, dynamic>>> _fetch(
      int page, String search) {
    return ref.read(attendanceRepositoryProvider).list(
          page,
          _search,
          locationId: _appliedLocationId,
          today: _appliedToday,
        );
  }

  void _onPageLoaded(PageMeta meta, Map<String, dynamic> extra) {
    trackPage(meta, extra);
    final s = extra['summary'];
    if (s is AttendanceSummary &&
        (s.total != _summary.total ||
            s.presentToday != _summary.presentToday ||
            s.absentToday != _summary.absentToday ||
            s.late != _summary.late)) {
      setState(() => _summary = s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(attendanceLocationsProvider);
    final signature = '$_appliedLocationId|$_appliedToday';

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Attendance'),
      body: Column(
        children: [
          Expanded(
            child: PagedListView<Map<String, dynamic>>(
              key: ValueKey('$signature|$_search'),
              searchable: false,
              padding: EdgeInsets.zero,
              separator: const SizedBox.shrink(),
              emptyMessage: 'No attendance records found.',
              fetchPage: _fetch,
              onPageLoaded: _onPageLoaded,
              header: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Today: ${_todayDateFmt.format(DateTime.now())}',
                        style: const TextStyle(
                            fontSize: 12, color: Hs.muted, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  _filterPanel(locations),
                  _summaryRow(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Name, mobile or employee code…',
                        prefixIcon: const Icon(Icons.search,
                            size: 20, color: Hs.muted),
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
                    leadingWidth: 34,
                    leadingLabel: '#',
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
    final present = asInt(m['Today']) == 1;
    final locColor = parseHexColor('${m['LocationColor'] ?? ''}');
    final name = orDash(m['EmployeeName']);
    final absent = asInt(m['TotAbsent']) ?? 0;
    final late = asInt(m['TotLate']) ?? 0;

    Widget num(int v, {Color? colorWhenNonZero}) => Text(
          '$v',
          style: TextStyle(
            color: v == 0 ? Hs.faint : (colorWhenNonZero ?? Hs.ink),
            fontWeight: v == 0 ? FontWeight.w400 : FontWeight.w700,
          ),
        );

    return HsTableRow(
      columns: _columns,
      group: _hScroll,
      leadingWidth: 34,
      leading: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('${m['SrNo'] ?? ''}',
            style: const TextStyle(fontSize: 13, color: Hs.inkSoft)),
      ),
      cells: [
        Text(orDash(m['EmployeeCode'])),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, color: Hs.ink)),
        PhoneLink(orDash(m['MobileNo'])),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: locColor ?? Hs.border,
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
              child: Text(orDash(m['LocationName']),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _statusPill(present),
        ),
        num(asInt(m['TotPresent']) ?? 0),
        num(absent, colorWhenNonZero: Hs.brandRed),
        num(late, colorWhenNonZero: const Color(0xFFE0A62B)),
        num(asInt(m['TotHalfday']) ?? 0),
      ],
    );
  }

  Widget _statusPill(bool present) {
    final color = present ? Hs.green : Hs.faint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        present ? 'Present' : 'Absent',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  Widget _summaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: _card('Total Employees', _summary.total, Hs.blue,
                  highlighted: _appliedToday == 'all'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _card('Present Today', _summary.presentToday, Hs.green,
                  highlighted: _appliedToday == 'present'),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _card('Absent Today', _summary.absentToday, Hs.brandRed,
                  highlighted: _appliedToday == 'absent'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _card('Late', _summary.late, const Color(0xFFE0A62B),
                  highlighted: _appliedToday == 'late'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(String label, int value, Color accent,
      {bool highlighted = false}) {
    // Accent bar is its own child: a non-uniform Border can't be combined
    // with a borderRadius. A matching full ring marks the active status
    // filter, mirroring the web card the current filter corresponds to.
    return InkWell(
      borderRadius: BorderRadius.circular(Hs.radiusSm),
      onTap: label == 'Total Employees'
          ? () => _applyStatus('all')
          : () => _applyStatus(
              label == 'Present Today'
                  ? 'present'
                  : label == 'Absent Today'
                      ? 'absent'
                      : 'late'),
      child: Container(
        decoration: BoxDecoration(
          color: Hs.surface,
          borderRadius: BorderRadius.circular(Hs.radiusSm),
          border: Border.all(
              color: highlighted ? accent : Hs.border,
              width: highlighted ? 1.4 : 1),
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
                  padding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Hs.muted,
                              letterSpacing: .2)),
                      const SizedBox(height: 4),
                      Text('$value',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Hs.ink)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterPanel(AsyncValue<List<AttendanceLocation>> locations) {
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
          const Text('ATTENDANCE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Hs.muted,
                  letterSpacing: .3)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _today,
            isExpanded: true,
            items: [
              for (final o in _todayOptions)
                DropdownMenuItem(value: o.$1, child: Text(o.$2)),
            ],
            onChanged: (v) => setState(() => _today = v ?? 'present'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _apply,
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

  Widget _colorChip(List<AttendanceLocation> list) {
    AttendanceLocation? loc;
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

  Widget _locationPicker(List<AttendanceLocation> list) {
    return DropdownButtonFormField<int?>(
      initialValue: _locationId,
      isExpanded: true,
      decoration: const InputDecoration(hintText: '-- All Locations --'),
      items: [
        const DropdownMenuItem<int?>(
            value: null, child: Text('-- All Locations --')),
        for (final l in list) DropdownMenuItem(value: l.id, child: Text(l.name)),
      ],
      onChanged: (v) => setState(() => _locationId = v),
    );
  }
}
