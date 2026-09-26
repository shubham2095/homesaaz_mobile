// lib/features/gate_entry/gate_entry_details_screen.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/item_fields_dialog.dart';
import '../../widgets/states.dart';
import 'gate_entry_repository.dart';

/// Column order mirrors web `gateEntry/details.blade.php`'s item table —
/// note this deliberately drops Sr No / Quality (which GRN's own item list
/// shows) and adds MRP, matching the screenshot exactly.
const _columns = <HsTableColumn>[
  HsTableColumn('Code', width: 80),
  HsTableColumn('Company', width: 130),
  HsTableColumn('Item Name', width: 120),
  HsTableColumn('Design', width: 100),
  HsTableColumn('Size', width: 60),
  HsTableColumn('Unit', width: 60),
  HsTableColumn('Qty', width: 50, alignEnd: true),
  HsTableColumn('Cost Price', width: 90, alignEnd: true),
  HsTableColumn('MRP', width: 90, alignEnd: true),
  HsTableColumn('Amount', width: 90, alignEnd: true),
  HsTableColumn('Tax %', width: 60, alignEnd: true),
  HsTableColumn('Supplier', width: 200),
];

final _dec2 = NumberFormat('#,##0.00', 'en_IN');

/// 2-decimal number, like the web table (845.15, 1,530.00).
String _n2(Object? v) {
  final n = asNum(v);
  return n == null ? '-' : _dec2.format(n);
}

String _rs2(Object? v) {
  final n = asNum(v);
  return n == null ? '-' : '₹${_dec2.format(n)}';
}

/// Whole numbers without trailing zeros (49, not 49.00).
String _qty(Object? v) {
  final n = asNum(v);
  if (n == null) return orDash(v);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/// Same image-server pattern as GRN — not proxied through the Laravel API.
String? _itemImageUrl(String? itemCode) {
  final code = itemCode?.trim();
  if (code == null || code.isEmpty || code == '-') return null;
  final host = Uri.parse(AppConfig.baseUrl).host;
  return 'http://$host:85/${Uri.encodeComponent(code)}.JPG';
}

final _detailsProvider = FutureProvider.family<Map<String, dynamic>,
    ({int id, int loc, String? from, String? to})>((ref, key) {
  return ref.watch(gateEntryRepositoryProvider).details(
        key.id,
        locationId: key.loc,
        dateFrom: key.from,
        dateTo: key.to,
      );
});

class GateEntryDetailsScreen extends ConsumerStatefulWidget {
  const GateEntryDetailsScreen({
    super.key,
    required this.grnId,
    required this.locationId,
    this.dateFrom,
    this.dateTo,
    this.header,
  });
  final int grnId;
  final int locationId;
  final String? dateFrom;
  final String? dateTo;

  /// The tapped row from the Gate Entry list, if navigated from there.
  final Map<String, dynamic>? header;

  @override
  ConsumerState<GateEntryDetailsScreen> createState() =>
      _GateEntryDetailsScreenState();
}

class _GateEntryDetailsScreenState
    extends ConsumerState<GateEntryDetailsScreen> {
  bool _downloading = false;
  final _hScroll = LinkedScrollControllerGroup();

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _downloadPdf() async {
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(gateEntryRepositoryProvider).downloadPdf(
            widget.grnId,
            locationId: widget.locationId,
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
          );
      final dir = await getTemporaryDirectory();
      final today = DateTime.now().toIso8601String().split('T').first;
      final file = File('${dir.path}/GateEntry_GRN_${widget.grnId}_$today.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done && mounted) {
        _snack('Could not open PDF: ${res.message}');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (e) {
      if (mounted) _snack('PDF download failed: $e');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (
      id: widget.grnId,
      loc: widget.locationId,
      from: widget.dateFrom,
      to: widget.dateTo,
    );
    final async = ref.watch(_detailsProvider(key));
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'Gate Entry Details',
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: _downloading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf, color: Hs.red),
            onPressed: _downloading ? null : _downloadPdf,
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(_detailsProvider(key)),
        ),
        data: (data) {
          final entry = (data['entry'] as Map?)?.cast<String, dynamic>() ??
              widget.header ??
              const <String, dynamic>{};
          final items = (data['items'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          final locationName = orDash(data['locationName']);
          final totalItems = asInt(data['totalItems']) ?? items.length;
          final totalQty = asNum(data['totalQty']) ?? 0;
          final totalAmount = asNum(data['totalAmount']) ?? 0;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  children: [
                    _headerCard(entry, locationName),
                    const SizedBox(height: 12),
                    _statRow(totalItems, totalQty, totalAmount),
                  ],
                ),
              ),
              if (items.isEmpty)
                const Expanded(child: EmptyView())
              else ...[
                HsTableHeader(
                  columns: _columns,
                  group: _hScroll,
                  leadingWidth: 56,
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox.shrink(),
                    itemBuilder: (context, i) => _itemRow(items[i]),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _headerCard(Map<String, dynamic> entry, String locationName) {
    return HsPanel(
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Hs.hairline,
              borderRadius: BorderRadius.circular(Hs.radiusSm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: parseGateEntryColor(ref
                            .watch(gateEntryLocationsProvider)
                            .valueOrNull?[widget.locationId]
                            ?.colorHex) ??
                        Hs.border,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    locationName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Hs.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Two tiles per row — the web's tile strip folded for a phone.
          LayoutBuilder(builder: (context, c) {
            const gap = 10.0;
            final w = (c.maxWidth - gap) / 2;
            final tiles = <(String, String)>[
              ('Floor Name',
                  orDash(findByNormalizedKey(entry, const ['FloorName']))),
              ('Entry No',
                  orDash(findByNormalizedKey(entry, const ['EntryNo']))),
              ('Entry Date',
                  prettyDate(findByNormalizedKey(entry, const ['EntryDate']))),
              ('Acc Name',
                  orDash(findByNormalizedKey(entry, const ['AccName']))),
              ('Company Name',
                  orDash(findByNormalizedKey(entry, const ['CompanyName']))),
              (
                'Goods Qty',
                (asNum(findByNormalizedKey(entry, const ['GoodsQty'])) ?? 0)
                    .toStringAsFixed(2)
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in tiles)
                  SizedBox(width: w, child: _headerField(t.$1, t.$2)),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _headerField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Hs.hairline,
        borderRadius: BorderRadius.circular(Hs.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Hs.faint,
                  letterSpacing: .3)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w700, color: Hs.ink)),
        ],
      ),
    );
  }

  Widget _statRow(int items, num qty, num amount) {
    return Row(
      children: [
        Expanded(child: _statBox('Items', '$items', Hs.blue)),
        const SizedBox(width: 10),
        Expanded(child: _statBox('Total Qty', _qty(qty), Hs.green)),
        const SizedBox(width: 10),
        Expanded(child: _statBox('Total Amount', _rs2(amount), Hs.brandRed)),
      ],
    );
  }

  Widget _statBox(String label, String value, Color color) {
    // Label on top, value below, blue accent bar on the left — as on the web.
    // (A non-uniform Border can't be combined with a borderRadius — Flutter
    // throws and the box renders blank — so the accent bar is its own child.)
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
            Container(width: 3, color: Hs.blue),
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
                            color: Hs.faint,
                            letterSpacing: .3)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: color)),
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

  Widget _itemRow(Map<String, dynamic> item) {
    final img = _itemImageUrl('${item['ItemCode'] ?? ''}');
    final code = '${item['ItemCode'] ?? ''}'.trim();
    return HsTableRow(
      columns: _columns,
      group: _hScroll,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: img == null
              ? Container(
                  width: 40,
                  height: 40,
                  color: Hs.hairline,
                  child: const Icon(Icons.inventory_2_outlined,
                      color: Hs.faint, size: 20),
                )
              : CachedNetworkImage(
                  imageUrl: img,
                  width: 40,
                  height: 40,
                  memCacheWidth: 120,
                  memCacheHeight: 120,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(width: 40, height: 40, color: Hs.hairline),
                  errorWidget: (_, __, ___) => Container(
                    width: 40,
                    height: 40,
                    color: Hs.hairline,
                    child: const Icon(Icons.broken_image_outlined,
                        color: Hs.faint, size: 18),
                  ),
                ),
        ),
      ),
      cells: [
        InkWell(
          onTap: code.isEmpty ? null : () => _showItemDialog(item, code, img),
          child: Text(orDash(item['ItemCode']),
              style: const TextStyle(
                  color: Hs.blue,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline)),
        ),
        Text(orDash(item['CompanyName'])),
        Text(orDash(item['ItemName'])),
        Text(orDash(item['DesignName'])),
        Text(orDash(item['Size'])),
        Text(orDash(item['Unit'])),
        Text(_qty(item['Qty'])),
        Text(_n2(item['CostPrice'])),
        Text(_n2(item['MRP'])),
        Text(_n2(item['Amount'])),
        Text(_n2(item['TaxRate'] ?? item['GST'])),
        Text(orDash(item['SupplierName'])),
      ],
    );
  }

  void _showItemDialog(Map<String, dynamic> item, String code, String? img) {
    showItemFieldsDialog(
      context,
      code: code,
      name: orDash(item['ItemName']),
      imageUrl: img,
      sections: [
        ItemFieldSection('Product Details', Icons.inventory_2_outlined, [
          ItemField('Company', orDash(item['CompanyName'])),
          ItemField('Design Name', orDash(item['DesignName'])),
          ItemField('Color', orDash(item['Color'])),
          ItemField('Size', orDash(item['Size'])),
          ItemField('Unit', orDash(item['Unit'])),
        ]),
        ItemFieldSection('Pricing & Quantity', Icons.payments_outlined, [
          ItemField('Quantity', orDash(item['Qty']),
              valueWidget: itemFieldChip(orDash(item['Qty']), Hs.red)),
          ItemField('Cost Price', money(item['CostPrice'])),
          ItemField('MRP', money(item['MRP'])),
          ItemField('Amount', money(item['Amount']),
              valueWidget: itemFieldChip(money(item['Amount']), Hs.green)),
          ItemField('Tax Rate', orDash(item['TaxRate'] ?? item['GST'])),
        ]),
        if ('${item['SupplierName'] ?? ''}'.trim().isNotEmpty)
          ItemFieldSection('Supplier', Icons.local_shipping_outlined, [
            ItemField('Supplier Name', orDash(item['SupplierName'])),
          ]),
      ],
    );
  }
}
