// lib/features/stock/stock_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/states.dart';
import 'stock_repository.dart';

/// Same 13 warehouse location codes as the "All Stock Details" table
/// (`stock_list_screen.dart`) — dynamic there via the backend's
/// `locationCodes`, but only this fixed set is wanted on this single-item
/// detail screen (per explicit spec, matching the web "Stock Item Details"
/// modal exactly).
const _locationCodes = [
  'AV', 'AVWH', 'FBD', 'GGN', 'HSD', 'HSN', 'KAVERI', 'KRN', 'LJP', 'LS',
  'MG', 'RJC', 'WH',
];

/// Web modal's section-accent colour (Bootstrap-ish indigo, distinct from
/// the app's teal primary — used only on this screen's section bars).
const _accent = Color(0xFF6F42C1);
const _itemCodeBlue = Color(0xFF0D6EFD);
const _supplierGray = Color(0xFF6C757D);
const _stripe = Color(0xFFFAFAFA);

class StockDetailScreen extends ConsumerWidget {
  const StockDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.watch(_provider(id));
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Stock Item Details'),
      body: future.when(
        loading: () => const LoadingView(),
        error: (e, _) =>
            ErrorView(message: '$e', onRetry: () => ref.invalidate(_provider(id))),
        data: (m) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section(
              '📦',
              'Basic Information',
              _table([
                _Row.widget('Item Code', _badge(orDash(m['ItemCode']), _itemCodeBlue)),
                _Row('Item Name', orDash(m['ItemName'])),
                _Row('Product Name', orDash(m['ProductName'])),
                _Row('Design Name', orDash(m['DesignName'])),
                _Row('Company', orDash(m['CompanyName'])),
                _Row('Section', orDash(m['SectionName'])),
                _Row('Color', orDash(m['Color'])),
                _Row('Size', orDash(m['Size'])),
              ]),
            ),
            const SizedBox(height: 20),
            _section(
              '💰',
              'Stock & Pricing',
              _table([
                _Row.widget('Stock Qty',
                    _badge((asNum(m['StkQty']) ?? 0).toStringAsFixed(0), Hs.red)),
                _Row('MRP', money(m['MRP'])),
                _Row('Rate', money(m['Rate'])),
                _Row('Unit', orDash(m['Unit'])),
                _Row('Cost', money(m['ACost'])),
                _Row('HSN Code', orDash(m['HSNCODE'])),
                _Row('GST', orDash(m['GST'])),
              ]),
            ),
            const SizedBox(height: 20),
            _section(
              '👤',
              'Item Details',
              _table([
                _Row('Quality', orDash(m['QualityName'])),
                _Row.widget('Supplier', _badge(orDash(m['SupplierName']), _supplierGray)),
                _Row('Supplier Mobile', orDash(m['SupplierMobileNo'])),
                _Row('Contact Person', orDash(m['ContactPerson'])),
              ]),
            ),
            const SizedBox(height: 20),
            _section(
              '🏬',
              'Warehouse Stock',
              _table([
                for (final code in _locationCodes)
                  _Row(code, (asNum(m[code]) ?? 0).toStringAsFixed(2)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of a [_table] — either plain text or a custom widget (a badge).
class _Row {
  const _Row(this.label, [this.value]) : valueWidget = null;
  const _Row.widget(this.label, this.valueWidget) : value = null;
  final String label;
  final String? value;
  final Widget? valueWidget;
}

Widget _section(String emoji, String title, Widget body) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Hs.ink,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      body,
    ],
  );
}

/// A literal bordered 2-column (Label | Value) table — one field per row,
/// with a light zebra stripe for readability.
Widget _table(List<_Row> rows) {
  return Table(
    border: TableBorder.all(color: Hs.border, width: 1),
    columnWidths: const {
      0: FractionColumnWidth(0.4),
      1: FractionColumnWidth(0.6),
    },
    children: [
      for (var i = 0; i < rows.length; i++)
        TableRow(
          decoration: BoxDecoration(color: i.isEven ? Hs.surface : _stripe),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(
                rows[i].label,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Hs.ink,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: rows[i].valueWidget ??
                  Text(
                    rows[i].value ?? '-',
                    style: const TextStyle(fontSize: 12.5, color: Hs.inkSoft),
                  ),
            ),
          ],
        ),
    ],
  );
}

Widget _badge(String text, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
  child: Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 11.5,
    ),
  ),
);

final _provider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) => ref.watch(stockRepositoryProvider).show(id),
);
