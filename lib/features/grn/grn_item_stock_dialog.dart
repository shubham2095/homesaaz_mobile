// lib/features/grn/grn_item_stock_dialog.dart
//
// Tapping an item Code in the GRN item list opens this — a polished popup
// showing that same row's data. No network call: every field here already
// came back with the GRN item list itself, so this is just a nicer
// re-presentation of it.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';

const _headerStart = Color(0xFF1E5FCE);
const _headerEnd = Color(0xFF0D9BCE);

void showGrnItemStockDialog(
  BuildContext context,
  Map<String, dynamic> item, {
  String? imageUrl,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _GrnItemStockDialog(item: item, imageUrl: imageUrl),
  );
}

class _GrnItemStockDialog extends StatelessWidget {
  const _GrnItemStockDialog({required this.item, this.imageUrl});
  final Map<String, dynamic> item;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final code = orDash(item['ItemCode']);
    final name = orDash(item['ItemName']);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Material(
          color: Hs.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: Colors.black45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(context, code, name),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _section('Product Details', Icons.inventory_2_outlined, [
                        _field('Company', orDash(item['CompanyName'])),
                        _field('Design Name', orDash(item['DesignName'])),
                        _field('Color', orDash(item['Color'])),
                        _field('Size', orDash(item['Size'])),
                        _field('Sr No', orDash(item['SrNo'] ?? item['SrlNo'])),
                        _field('Unit', orDash(item['Unit'])),
                        _field('Quality',
                            orDash(item['QualityName'] ?? item['Quality'])),
                      ]),
                      const SizedBox(height: 18),
                      _section('Pricing & Quantity', Icons.payments_outlined, [
                        _field('Quantity', orDash(item['Qty']),
                            valueWidget: _chip(
                                orDash(item['Qty']), Hs.red)),
                        _field('Cost Price', money(item['CostPrice'])),
                        _field('Amount', money(item['Amount']),
                            valueWidget: _chip(
                                money(item['Amount']), Hs.green)),
                        _field(
                            'Tax Rate', orDash(item['TaxRate'] ?? item['GST'])),
                      ]),
                      if ('${item['SupplierName'] ?? ''}'.trim().isNotEmpty) ...[
                        const SizedBox(height: 18),
                        _section('Supplier', Icons.local_shipping_outlined, [
                          _field('Supplier Name', orDash(item['SupplierName'])),
                        ]),
                      ],
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

  Widget _header(BuildContext context, String code, String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_headerStart, _headerEnd],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null
                ? const Icon(Icons.inventory_2_outlined,
                    color: Hs.faint, size: 30)
                : CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    memCacheHeight: 200,
                    errorWidget: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Hs.faint,
                        size: 26),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: .35)),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white.withValues(alpha: .16),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _section(String title, IconData icon, List<Widget> fields) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 16, color: _headerStart),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: _headerStart,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        decoration: BoxDecoration(
          color: Hs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Hs.border),
          boxShadow: Hs.cardShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: fields),
      ),
    ],
  );
}

Widget _field(String label, String value, {Widget? valueWidget}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Hs.hairline)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Hs.muted,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerRight,
            child: valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Hs.ink,
                  ),
                ),
          ),
        ),
      ],
    ),
  );
}

Widget _chip(String text, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
  child: Text(
    text,
    style: const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
    ),
  ),
);
