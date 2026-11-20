// lib/features/home_stay/stay_table.dart
import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_footer_mixin.dart';
import '../../widgets/paged_list_view.dart';

/// The web's hostel list pages (Pending Rent, Student Details, Bed Occupancy,
/// New Student — for ALFOHOMES and Pearl Stay alike) as one table screen:
/// a header row, a pinned S.No column, one row per record with an eye
/// "view" button that opens the record's details, search, infinite scroll and
/// the "Showing 1 to N of Total" footer. The header stays visible when there
/// is no data, with [emptyMessage] under it — like the web's empty table.
class StayTableScreen extends StatefulWidget {
  const StayTableScreen({
    super.key,
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.columns,
    required this.fetchPage,
    required this.cells,
    required this.detailTitle,
    required this.detailRows,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;

  /// The data columns, in the web's order; S.No and Action are added here.
  final List<HsTableColumn> columns;
  final PageFetcher<Map<String, dynamic>> fetchPage;

  /// One widget per entry of [columns].
  final List<Widget> Function(Map<String, dynamic> row) cells;

  final String Function(Map<String, dynamic> row) detailTitle;
  final List<(String label, String value)> Function(Map<String, dynamic> row)
      detailRows;

  @override
  State<StayTableScreen> createState() => _StayTableScreenState();
}

class _StayTableScreenState extends State<StayTableScreen>
    with PagedFooterMixin<StayTableScreen> {
  final _hScroll = LinkedScrollControllerGroup();

  late final List<HsTableColumn> _columns = [
    ...widget.columns,
    const HsTableColumn('Action', width: 76),
  ];

  void _view(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.detailTitle(row),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              for (final r in widget.detailRows(row)) HsRow(r.$1, r.$2),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(title: widget.title),
      body: Column(
        children: [
          Expanded(
            child: PagedListView<Map<String, dynamic>>(
              searchHint: widget.searchHint,
              emptyMessage: widget.emptyMessage,
              padding: const EdgeInsets.only(bottom: 24),
              separator: const SizedBox.shrink(),
              // Search on top, then the table header, then the rows — the
              // web's order. The header is the list's first item, so it is
              // still there (with the empty message under it) when there is
              // no data.
              header: HsTableHeader(
                columns: _columns,
                group: _hScroll,
                leadingWidth: 56,
                leadingLabel: 'S.No',
              ),
              fetchPage: widget.fetchPage,
              onPageLoaded: trackPage,
              indexedItemBuilder: (context, m, index) => HsTableRow(
                columns: _columns,
                group: _hScroll,
                leadingWidth: 56,
                onTap: () => _view(m),
                leading: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${index + 1}',
                        style: const TextStyle(color: Hs.muted, fontSize: 13)),
                  ),
                ),
                cells: [
                  ...widget.cells(m),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => _view(m),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 36,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border.all(color: Hs.blue),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.visibility_outlined,
                            size: 17, color: Hs.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (footerTotal > 0) footerBar(),
        ],
      ),
    );
  }
}

/// A table cell's text in the strong style the web uses for the main column.
Widget stayName(Object? v) => Text(
      '${v ?? ''}'.trim().isEmpty ? '-' : '$v'.trim(),
      style: const TextStyle(fontWeight: FontWeight.w600, color: Hs.ink),
    );
