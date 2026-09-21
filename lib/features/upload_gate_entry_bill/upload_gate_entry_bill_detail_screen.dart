// lib/features/upload_gate_entry_bill/upload_gate_entry_bill_detail_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/kv_row.dart';
import '../../widgets/states.dart';
import 'upload_gate_entry_bill_form.dart';
import 'upload_gate_entry_bill_repository.dart';

final _detailProvider = FutureProvider.family<Map<String, dynamic>, int>(
  (ref, id) async {
    final data =
        await ref.read(apiClientProvider).getData('/uploadgateentrybill/$id');
    return (data as Map).cast<String, dynamic>();
  },
);

class UploadGateEntryBillDetailScreen extends ConsumerWidget {
  const UploadGateEntryBillDetailScreen({super.key, required this.id});
  final int id;

  void _snack(BuildContext context, String m) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, String status) async {
    try {
      final repo = ref.read(uploadGateEntryBillRepositoryProvider);
      if (status == 'Approved') {
        await repo.approve(id);
      } else {
        await repo.reject(id);
      }
      ref.invalidate(_detailProvider(id));
      if (context.mounted) _snack(context, 'Invoice $status');
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Update failed: $e');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: const Text('This will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Hs.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(uploadGateEntryBillRepositoryProvider).delete(id);
      if (context.mounted) {
        _snack(context, 'Invoice deleted');
        context.pop();
      }
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, 'Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_detailProvider(id));
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'Gate Entry Bill',
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              if (await showUploadGateEntryBillForm(context, id: id) == true) {
                ref.invalidate(_detailProvider(id));
              }
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: Hs.red),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(_detailProvider(id)),
        ),
        data: (m) {
          final img = '${m['ImagePath'] ?? ''}';
          final status = '${m['ApprovalStatus'] ?? 'Pending'}';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (img.startsWith('http'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: img,
                      fit: BoxFit.contain,
                      errorWidget: (_, __, ___) =>
                          const SizedBox(height: 80, child: Icon(Icons.image)),
                    ),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KvRow('Invoice No', m['InvoiceNumber']),
                      KvRow('Status', status,
                          valueColor: status == 'Approved'
                              ? Hs.green
                              : status == 'Rejected'
                                  ? Hs.red
                                  : Hs.amber),
                      KvRow('Approved By', m['ApprovedByAdminName']),
                      KvRow('Approved At', m['ApprovedAt']),
                      KvRow('Created', m['CreatedDate']),
                      KvRow('Notes', m['ApprovalNotes']),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (status != 'Approved')
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Hs.green),
                      onPressed: () => _setStatus(context, ref, 'Approved'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                    ),
                  ),
                ),
              if (status != 'Rejected')
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Hs.red,
                        side: const BorderSide(color: Hs.red)),
                    onPressed: () => _setStatus(context, ref, 'Rejected'),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
