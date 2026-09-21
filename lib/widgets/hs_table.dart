// lib/widgets/hs_table.dart
//
// A plain HTML `<table>` with `overflow-x:auto` (Bootstrap `.table-responsive`)
// has no sticky header — scrolling the page scrolls the header away too, and
// the whole table just scrolls horizontally as one unit. This reproduces
// that: header and every row share one horizontal scroll position (via
// [LinkedScrollControllerGroup]) while the outer list still scrolls
// vertically through the normal [PagedListView]/[ListView] machinery, so
// infinite-scroll pagination keeps working unmodified.
import 'package:flutter/material.dart';

import '../app/tokens.dart';

/// Keeps N [ScrollController]s moving in lockstep.
class LinkedScrollControllerGroup {
  final Set<_LinkedScrollController> _controllers = {};
  bool _offsetChangeInProgress = false;
  double _offset = 0;

  ScrollController newController() {
    final c = _LinkedScrollController(this, initialScrollOffset: _offset);
    _controllers.add(c);
    return c;
  }

  void _dispose(_LinkedScrollController c) => _controllers.remove(c);

  void _onOffsetChanged(_LinkedScrollController source, double offset) {
    if (_offsetChangeInProgress) return;
    _offsetChangeInProgress = true;
    _offset = offset;
    for (final c in _controllers) {
      if (c != source && c.hasClients && c.offset != offset) {
        c.jumpTo(offset);
      }
    }
    _offsetChangeInProgress = false;
  }
}

class _LinkedScrollController extends ScrollController {
  _LinkedScrollController(this._group, {super.initialScrollOffset});
  final LinkedScrollControllerGroup _group;

  @override
  void dispose() {
    _group._dispose(this);
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (hasClients) _group._onOffsetChanged(this, offset);
    super.notifyListeners();
  }
}

class HsTableColumn {
  const HsTableColumn(this.label, {this.width = 110, this.alignEnd = false});
  final String label;
  final double width;
  final bool alignEnd;
}

/// Bootstrap 5's actual default `.table` cell padding (`.5rem .5rem`).
const _bootstrapCellPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 8);

/// The table header — web `<thead class="table-light">`.
class HsTableHeader extends StatefulWidget {
  const HsTableHeader({
    super.key,
    required this.columns,
    required this.group,
    this.leadingWidth = 0,
    this.leadingLabel,
    this.cellPadding = _bootstrapCellPadding,
  });

  final List<HsTableColumn> columns;
  final LinkedScrollControllerGroup group;
  final double leadingWidth;

  /// Header text for the pinned leading cell (e.g. "S.No"). Left blank
  /// (image/colour swatch columns) when null.
  final String? leadingLabel;

  /// Cell padding — defaults to plain Bootstrap `.table` cells (`.5rem
  /// .5rem` = 8px/8px, what Stock and Locations actually use). Pass a
  /// wider value to match a page with its own custom table CSS (e.g.
  /// Upload Gate Entry Bill's `.invoices-table`, 12px/14px).
  final EdgeInsets cellPadding;

  @override
  State<HsTableHeader> createState() => _HsTableHeaderState();
}

class _HsTableHeaderState extends State<HsTableHeader> {
  late final ScrollController _controller = widget.group.newController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA), // Bootstrap table-light
        border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6), width: 2)),
      ),
      child: Row(
        children: [
          if (widget.leadingWidth > 0)
            SizedBox(
              width: widget.leadingWidth,
              child: widget.leadingLabel == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        widget.leadingLabel!,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Hs.ink,
                        ),
                      ),
                    ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in widget.columns)
                    Container(
                      width: c.width,
                      padding: widget.cellPadding,
                      alignment: c.alignEnd
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Hs.ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One data row — web `<tbody><tr><td>…`.
class HsTableRow extends StatefulWidget {
  const HsTableRow({
    super.key,
    required this.columns,
    required this.cells,
    required this.group,
    this.leading,
    this.leadingWidth = 0,
    this.onTap,
    this.striped = false,
    this.cellPadding = _bootstrapCellPadding,
    this.backgroundColor,
  });

  final List<HsTableColumn> columns;
  final List<Widget> cells;
  final LinkedScrollControllerGroup group;
  final Widget? leading;
  final double leadingWidth;
  final VoidCallback? onTap;
  final bool striped;
  final EdgeInsets cellPadding;

  /// Overrides the striped/plain background — used to tint a row with the
  /// selected location's colour (Stock table, location filter).
  final Color? backgroundColor;

  @override
  State<HsTableRow> createState() => _HsTableRowState();
}

class _HsTableRowState extends State<HsTableRow> {
  late final ScrollController _controller = widget.group.newController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            widget.backgroundColor ??
            (widget.striped ? const Color(0xFFFBFBFB) : Hs.surface),
        border: const Border(bottom: BorderSide(color: Color(0xFFDEE2E6))),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Row(
          children: [
            if (widget.leadingWidth > 0)
              SizedBox(width: widget.leadingWidth, child: widget.leading),
            Expanded(
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < widget.columns.length; i++)
                      Container(
                        width: widget.columns[i].width,
                        padding: widget.cellPadding,
                        alignment: widget.columns[i].alignEnd
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            fontSize: 13,
                            color: Hs.inkSoft,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          child: widget.cells[i],
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
}
