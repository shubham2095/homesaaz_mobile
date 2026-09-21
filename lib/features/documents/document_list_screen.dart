// lib/features/documents/document_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_list_view.dart';
import 'document_repository.dart';

class DocumentListScreen extends ConsumerStatefulWidget {
  const DocumentListScreen({super.key});
  @override
  ConsumerState<DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends ConsumerState<DocumentListScreen> {
  String? _docTypeName;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(documentRepositoryProvider);
    final types = ref.watch(documentTypesProvider);

    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Document Download'),
      body: Column(
        children: [
          types.maybeWhen(
            data: (list) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                initialValue: _docTypeName,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Document Type'),
                hint: const Text('-- Select Type --'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All types')),
                  for (final t in list)
                    DropdownMenuItem(
                      value: '${t['DocTypeName']}',
                      child: Text('${t['DocTypeName']}'),
                    ),
                ],
                onChanged: (v) => setState(() => _docTypeName = v),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: PagedListView<DocRow>(
              key: ValueKey(_docTypeName),
              searchHint: 'Account name, document no or item code…',
              fetchPage: (page, search) =>
                  repo.list(page, search, docType: _docTypeName),
              itemBuilder: (context, d) => HsListCard(
                onTap: () => context.push('/documents/${d.id}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(orDash(d.vendor),
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Hs.ink)),
                        ),
                        Text(d.amount == null ? '' : money(d.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, color: Hs.green)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Order mirrors web's card-row list
                    // (documentDownload/list.blade.php): Vendor [title],
                    // Doc Type, Doc No, Item Code, Location, Date.
                    HsRow(
                      'Doc Type',
                      d.docType,
                      bottomDivider: true,
                      valueWidget: d.docType.trim().isEmpty
                          ? null
                          : Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  // Web `.doc-type-badge`: #E3F2FD bg / #0052CC text.
                                  color: const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  d.docType,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0052CC),
                                  ),
                                ),
                              ),
                            ),
                    ),
                    HsRow('Doc No', orDash(d.docNo), bottomDivider: true),
                    HsRow('Item Code', orDash(d.itemCode), bottomDivider: true),
                    HsRow('Location', orDash(d.location), bottomDivider: true),
                    HsRow('Date', prettyDate(d.date)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
