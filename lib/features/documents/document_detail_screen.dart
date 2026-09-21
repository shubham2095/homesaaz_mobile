// lib/features/documents/document_detail_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/format.dart';
import '../../widgets/kv_row.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/states.dart';
import 'document_repository.dart';

final _detailProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) => ref.watch(documentRepositoryProvider).show(id),
);

class DocumentDetailScreen extends ConsumerStatefulWidget {
  const DocumentDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<DocumentDetailScreen> createState() => _State();
}

class _State extends ConsumerState<DocumentDetailScreen> {
  bool _downloading = false;

  Future<void> _download(String billNo) async {
    setState(() => _downloading = true);
    try {
      final bytes =
          await ref.read(documentRepositoryProvider).downloadBytes(widget.id);
      final dir = await getTemporaryDirectory();
      final safe = billNo.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/$safe.pdf');
      await file.writeAsBytes(bytes, flush: true);
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open PDF: ${res.message}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Download failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_detailProvider(widget.id));
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Document Detail'),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(_detailProvider(widget.id)),
        ),
        data: (m) {
          final hasPdf = m['hasPdf'] == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KvRow('Doc No', m['docNo']),
                      KvRow('Type', m['docType']),
                      KvRow('Date', prettyDate(m['docDate'])),
                      KvRow('Vendor', m['vendorName']),
                      KvRow('Item Code', m['itemCode']),
                      KvRow('Location', m['location']),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: (!hasPdf || _downloading)
                    ? null
                    : () => _download('${m['docNo'] ?? 'document'}'),
                icon: _downloading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(hasPdf ? 'Download PDF' : 'No PDF attached'),
              ),
            ],
          );
        },
      ),
    );
  }
}
