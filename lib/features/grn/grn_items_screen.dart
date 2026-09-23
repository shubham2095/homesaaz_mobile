// lib/features/grn/grn_items_screen.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../widgets/states.dart';
import 'grn_item_stock_dialog.dart';
import 'grn_repository.dart';

/// Column order mirrors web `grn/Detail.blade.php`'s `<thead>` — Item Image
/// is the pinned leading column, the rest scroll horizontally.
const _columns = <HsTableColumn>[
  HsTableColumn('Code', width: 80),
  HsTableColumn('Company', width: 130),
  HsTableColumn('Item Name', width: 120),
  HsTableColumn('Design Name', width: 100),
  HsTableColumn('Color', width: 90),
  HsTableColumn('Sr No', width: 60),
  HsTableColumn('Unit', width: 60),
  HsTableColumn('Quality', width: 90),
  HsTableColumn('Qty', width: 50, alignEnd: true),
  HsTableColumn('Size', width: 60),
  HsTableColumn('Cost Price', width: 90, alignEnd: true),
  HsTableColumn('Amount', width: 90, alignEnd: true),
  HsTableColumn('Tax Rate', width: 70, alignEnd: true),
  HsTableColumn('Supplier Name', width: 200),
];

/// The web app doesn't serve item images through the Laravel API at all —
/// it builds the URL straight from the item code against a separate image
/// server: `http://<host>:85/{ItemCode}.JPG` (see grn/Detail.blade.php).
String? _grnItemImageUrl(String? itemCode) {
  final code = itemCode?.trim();
  if (code == null || code.isEmpty || code == '-') return null;
  final host = Uri.parse(AppConfig.baseUrl).host;
  return 'http://$host:85/${Uri.encodeComponent(code)}.JPG';
}

final _itemsProvider = FutureProvider.family<List<Map<String, dynamic>>,
    ({int id, int loc})>((ref, key) {
  return ref.watch(grnRepositoryProvider).items(key.id, key.loc);
});

class GrnItemsScreen extends ConsumerStatefulWidget {
  const GrnItemsScreen({
    super.key,
    required this.grnId,
    required this.locationId,
    this.header,
  });
  final int grnId;
  final int locationId;

  /// The tapped row from the GRN list, if navigated from there — carries
  /// GmNo / FloorName / GrnDate / Supplier / Billing for the header card
  /// and the date the PDF endpoint needs.
  final Map<String, dynamic>? header;

  @override
  ConsumerState<GrnItemsScreen> createState() => _GrnItemsScreenState();
}

class _GrnItemsScreenState extends ConsumerState<GrnItemsScreen> {
  bool _downloading = false;
  final _hScroll = LinkedScrollControllerGroup();

  String? get _grnDate {
    final v = widget.header?['GrnDate'];
    if (v == null) return null;
    final s = '$v';
    // Accept either an ISO-ish string or a DateTime.tryParse-able value.
    final d = DateTime.tryParse(s);
    if (d != null) {
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    return s.split(' ').first; // already yyyy-mm-dd-ish
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _downloadPdf() async {
    final date = _grnDate;
    if (date == null) {
      _snack('GRN date unknown — open this GRN from the list to download.');
      return;
    }
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(grnRepositoryProvider).downloadPdf(
            widget.grnId,
            locationId: widget.locationId,
            date: date,
          );
      final dir = await getTemporaryDirectory();
      final gmNo = widget.header?['GmNo'] ?? widget.header?['GMNo'] ?? widget.grnId;
      final today = DateTime.now().toIso8601String().split('T').first;
      final safe = '$gmNo'.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/GRN_${safe}_$today.pdf');
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
    final key = (id: widget.grnId, loc: widget.locationId);
    final async = ref.watch(_itemsProvider(key));
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'GRN #${widget.grnId} Details',
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
          onRetry: () => ref.invalidate(_itemsProvider(key)),
        ),
        data: (items) {
          return Column(
            children: [
              if (widget.header != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _headerCard(widget.header!),
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

  Widget _headerCard(Map<String, dynamic> h) {
    return HsPanel(
      margin: EdgeInsets.zero,
      child: Wrap(
        spacing: 22,
        runSpacing: 10,
        children: [
          _headerField(
              'GRN No',
              orDash(h['GmNo'] ??
                  h['GRNNo'] ??
                  h['GrnNo'] ??
                  h['EntryNo'] ??
                  h['GMNo'] ??
                  h['GRNID'])),
          _headerField('Floor', orDash(h['FloorName'])),
          _headerField('GRN Date', prettyDate(h['GrnDate'])),
          _headerField('Billing', orDash(h['Billno'] ?? h['Billing'])),
          if ('${h['Supplier'] ?? ''}'.trim().isNotEmpty)
            _headerField('Supplier', '${h['Supplier']}', wide: true),
        ],
      ),
    );
  }

  Widget _headerField(String label, String value, {bool wide = false}) {
    return SizedBox(
      width: wide ? double.infinity : 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Hs.faint,
                  letterSpacing: .3)),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Hs.ink)),
        ],
      ),
    );
  }

  Widget _itemRow(Map<String, dynamic> item) {
    final img = _grnItemImageUrl('${item['ItemCode'] ?? ''}');
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
                  // Caps the decoded bitmap to thumbnail size instead of
                  // decoding the full-resolution photo for a 40x40 display.
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
          onTap: code.isEmpty
              ? null
              : () => showGrnItemStockDialog(context, item, imageUrl: img),
          child: Text(orDash(item['ItemCode']),
              style: const TextStyle(
                  color: Hs.blue,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline)),
        ),
        Text(orDash(item['CompanyName'])),
        Text(orDash(item['ItemName'])),
        Text(orDash(item['DesignName'])),
        Text(orDash(item['Color'])),
        Text(orDash(item['SrNo'] ?? item['SrlNo'])),
        Text(orDash(item['Unit'])),
        Text(orDash(item['QualityName'] ?? item['Quality'])),
        Text(orDash(item['Qty'])),
        Text(orDash(item['Size'])),
        Text(money(item['CostPrice'])),
        Text(money(item['Amount'])),
        Text(orDash(item['TaxRate'] ?? item['GST'])),
        Text(orDash(item['SupplierName'])),
      ],
    );
  }
}
