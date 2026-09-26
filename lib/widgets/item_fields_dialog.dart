// lib/widgets/item_fields_dialog.dart
//
// Shared "premium" item-details popup — used by both GRN and Gate Entry
// item lists (tapping a row's Code). No network call: every field shown
// here already came back with the list itself, this is just a nicer
// re-presentation of it, grouped into sections.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../app/tokens.dart';

const _headerStart = Color(0xFF1E5FCE);
const _headerEnd = Color(0xFF0D9BCE);

/// One field row inside an [ItemFieldSection].
class ItemField {
  const ItemField(this.label, this.value, {this.valueWidget});
  final String label;
  final String value;
  final Widget? valueWidget;
}

/// One grouped card of [ItemField]s under an icon + title.
class ItemFieldSection {
  const ItemFieldSection(this.title, this.icon, this.fields);
  final String title;
  final IconData icon;
  final List<ItemField> fields;
}

/// A ready-made highlighted pill for a numeric field (Qty, Amount, …).
Widget itemFieldChip(String text, Color bg) => Container(
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

void showItemFieldsDialog(
  BuildContext context, {
  required String code,
  required String name,
  required List<ItemFieldSection> sections,
  String? imageUrl,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ItemFieldsDialog(
      code: code,
      name: name,
      sections: sections,
      imageUrl: imageUrl,
    ),
  );
}

class _ItemFieldsDialog extends StatelessWidget {
  const _ItemFieldsDialog({
    required this.code,
    required this.name,
    required this.sections,
    this.imageUrl,
  });
  final String code;
  final String name;
  final List<ItemFieldSection> sections;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
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
              _header(context),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: 18),
                        _section(sections[i]),
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

  Widget _header(BuildContext context) {
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

  Widget _section(ItemFieldSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(section.icon, size: 16, color: _headerStart),
            const SizedBox(width: 6),
            Text(
              section.title.toUpperCase(),
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
          child: Column(children: [for (final f in section.fields) _field(f)]),
        ),
      ],
    );
  }

  Widget _field(ItemField field) {
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
              field.label,
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
              child: field.valueWidget ??
                  Text(
                    field.value,
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
}
