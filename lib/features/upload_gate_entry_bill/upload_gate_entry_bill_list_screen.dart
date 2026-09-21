// lib/features/upload_gate_entry_bill/upload_gate_entry_bill_list_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_dialog.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/paged_list_view.dart';
import 'upload_gate_entry_bill_form.dart';
import 'upload_gate_entry_bill_repository.dart';

/// Column order mirrors web `uploadgateentrybill/list.blade.php`'s
/// `<thead>` — a genuine horizontal-scroll table on web too (no mobile
/// card fallback), `min-width:600px`.
const _columns = <HsTableColumn>[
  HsTableColumn('Status', width: 130),
  HsTableColumn('Approved By', width: 130),
  HsTableColumn('Date', width: 110),
  HsTableColumn('Image', width: 70),
  HsTableColumn('Actions', width: 90),
];

final _repoProvider = Provider((ref) => _Repo(ref));

class _Repo {
  _Repo(this.ref);
  final Ref ref;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/uploadgateentrybill/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

/// This page's own local CSS vars (`uploadgateentrybill/list.blade.php`
/// `:root`), distinct from the app's global teal `Hs.blue` — matched
/// literally for pixel parity, same pattern as `user_form.dart`'s header.
const _primaryBlue = Color(0xFF0052CC);
const _textDark = Color(0xFF333333);
const _borderGray = Color(0xFFDDDDDD);

class UploadGateEntryBillListScreen extends ConsumerStatefulWidget {
  const UploadGateEntryBillListScreen({super.key});
  @override
  ConsumerState<UploadGateEntryBillListScreen> createState() =>
      _UploadGateEntryBillListScreenState();
}

class _UploadGateEntryBillListScreenState
    extends ConsumerState<UploadGateEntryBillListScreen> {
  int _reload = 0;
  final _hScroll = LinkedScrollControllerGroup();
  final _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _debounce;
  void _refresh() => setState(() => _reload++);

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      setState(() => _search = v.trim());
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  /// Web opens `ImagePath` in a new browser tab; the mobile equivalent is
  /// a full-screen dialog viewer.
  void _viewImage(String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            errorWidget: (_, __, ___) => const SizedBox(
              height: 200,
              child: Center(child: Icon(Icons.broken_image_outlined, size: 40)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _add() async {
    if (await showUploadGateEntryBillForm(context) == true) {
      _snack('Invoice added');
      _refresh();
    }
  }

  Future<void> _edit(int id) async {
    if (await showUploadGateEntryBillForm(context, id: id) == true) {
      _snack('Invoice updated');
      _refresh();
    }
  }

  Future<void> _delete(int id, String invoiceNumber) async {
    final ok = await showHsConfirmDialog(
      context,
      title: 'Delete Invoice?',
      text: '$invoiceNumber will be permanently removed.',
    );
    if (!ok) return;
    try {
      await ref.read(uploadGateEntryBillRepositoryProvider).delete(id);
      _snack('Invoice deleted');
      _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  Future<void> _setStatus(int id, String status) async {
    try {
      final repo = ref.read(uploadGateEntryBillRepositoryProvider);
      if (status == 'Approved') {
        await repo.approve(id);
      } else if (status == 'Rejected') {
        await repo.reject(id);
      } else {
        return; // no "revert to pending" endpoint
      }
      _snack('Invoice $status');
      _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Status update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(_repoProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'Upload Gate Entry Bill',
        actions: [
          IconButton(
            tooltip: 'Add Invoice',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _add,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search invoice…',
                prefixIcon: const Icon(Icons.search, size: 20, color: Hs.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 42, minHeight: 42),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        splashRadius: 18,
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearchChanged('');
                        },
                      ),
              ),
            ),
          ),
          HsTableHeader(
            columns: _columns,
            group: _hScroll,
            leadingWidth: 100,
            cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          ),
          Expanded(
            child: PagedListView<Map<String, dynamic>>(
              key: ValueKey('$_reload|$_search'),
              searchable: false,
              padding: EdgeInsets.zero,
              separator: const SizedBox.shrink(),
              fetchPage: (page, _) => repo.list(page, _search),
              itemBuilder: (context, m) {
                final id = asInt(m['Id']);
                final status = '${m['ApprovalStatus'] ?? 'Pending'}';
                final statusOptions = {'Pending', 'Approved', 'Rejected', status};
                final imagePath = '${m['ImagePath'] ?? ''}';
                return HsTableRow(
                  columns: _columns,
                  group: _hScroll,
                  leadingWidth: 100,
                  cellPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  onTap: id == null
                      ? null
                      : () => context.push('/upload-gate-entry-bill/$id'),
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      orDash(m['InvoiceNumber']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Hs.ink,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  cells: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border.all(color: _borderGray),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: status,
                          isDense: true,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _textDark,
                          ),
                          items: [
                            for (final s in statusOptions)
                              DropdownMenuItem(value: s, child: Text(s)),
                          ],
                          onChanged: id == null
                              ? null
                              : (v) {
                                  if (v != null && v != status) {
                                    _setStatus(id, v);
                                  }
                                },
                        ),
                      ),
                    ),
                    Text(orDash(
                        m['ApprovedByAdminName'] ?? m['ApprovedByAdminID'])),
                    Text(orDash(m['CreatedDate'])),
                    imagePath.isEmpty
                        ? const Text('-')
                        : _iconBtn(
                            tooltip: 'View image',
                            icon: Icons.image_outlined,
                            color: _primaryBlue,
                            onPressed: () => _viewImage(imagePath),
                          ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (id != null)
                          _iconBtn(
                            tooltip: 'Edit',
                            icon: Icons.edit_outlined,
                            color: Hs.amber,
                            onPressed: () => _edit(id),
                          ),
                        if (id != null) ...[
                          const SizedBox(width: 4),
                          _iconBtn(
                            tooltip: 'Delete',
                            icon: Icons.delete_outline,
                            color: Hs.red,
                            onPressed: () =>
                                _delete(id, orDash(m['InvoiceNumber'])),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Web `.btn-icon` — a 32x32 outlined square button per action, colour
  /// keyed per action (view=blue, edit=amber, delete=red).
  Widget _iconBtn({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onPressed,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}
