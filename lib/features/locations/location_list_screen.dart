// lib/features/locations/location_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_dialog.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_table.dart';
import '../../widgets/paged_footer_mixin.dart';
import '../../widgets/paged_list_view.dart';
import 'location_form.dart';
import 'location_repository.dart';

/// Column order mirrors web `locations/list.blade.php`'s `<thead>`. S.No is
/// the pinned leading cell (via PagedListView's `indexedItemBuilder`).
const _columns = <HsTableColumn>[
  HsTableColumn('Location Code', width: 120),
  HsTableColumn('Location Name', width: 170),
  HsTableColumn('Address', width: 220),
  HsTableColumn('GST Number', width: 130),
  HsTableColumn('Color', width: 60),
  HsTableColumn('Actions', width: 90),
];

class LocationListScreen extends ConsumerStatefulWidget {
  const LocationListScreen({super.key});
  @override
  ConsumerState<LocationListScreen> createState() => _LocationListScreenState();
}

class _LocationListScreenState extends ConsumerState<LocationListScreen>
    with PagedFooterMixin<LocationListScreen> {
  int _reload = 0;
  final _hScroll = LinkedScrollControllerGroup();

  void _refresh() => setState(() {
    _reload++;
    resetFooter();
  });

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  Future<void> _add() async {
    if (await showLocationForm(context) == true) {
      _snack('Location added');
      _refresh();
    }
  }

  Future<void> _edit(LocationRow l) async {
    if (await showLocationForm(context, locationId: l.id) == true) {
      _snack('Location updated');
      _refresh();
    }
  }

  Future<void> _delete(LocationRow l) async {
    // Web uses a plain native confirm() for this one — no real "styling" to
    // mirror, so the shared HomeSaaz confirm dialog is used for consistency
    // with Users/Upload Gate Entry Bill instead.
    final ok = await showHsConfirmDialog(
      context,
      title: 'Delete Location?',
      text: '${l.name} (${l.code}) will be removed.',
    );
    if (!ok) return;
    try {
      await ref.read(locationRepositoryProvider).delete(l.id);
      _snack('Location deleted');
      _refresh();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Delete failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(locationRepositoryProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: HsAppBar(
        title: 'Location Management',
        actions: [
          IconButton(
            tooltip: 'Add Location',
            icon: const Icon(Icons.add_location_alt_outlined),
            onPressed: _add,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add Location'),
      ),
      body: Column(
        children: [
          HsTableHeader(
            columns: _columns,
            group: _hScroll,
            leadingWidth: 56,
            leadingLabel: 'S.No',
          ),
          Expanded(
            child: PagedListView<LocationRow>(
              key: ValueKey(_reload),
              searchHint: 'Search by location name or code…',
              // Bottom clearance for the "Add Location" FAB — a runtime
              // check on-device caught it otherwise covering the last rows.
              padding: const EdgeInsets.only(bottom: 88),
              separator: const SizedBox.shrink(),
              fetchPage: repo.list,
              onPageLoaded: trackPage,
              indexedItemBuilder: (context, l, index) {
                final swatch = locationHexToColor(l.colorHex);
                return HsTableRow(
                  columns: _columns,
                  group: _hScroll,
                  leadingWidth: 56,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Hs.muted, fontSize: 13),
                    ),
                  ),
                  cells: [
                    Text(orDash(l.code)),
                    Text(
                      orDash(l.name),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Hs.ink,
                      ),
                    ),
                    Text(orDash(l.address)),
                    Text(orDash(l.gst)),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: swatch ?? Hs.hairline,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: Hs.border),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.edit_outlined,
                            size: 19,
                            color: Hs.blue,
                          ),
                          onPressed: () => _edit(l),
                        ),
                        IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 19,
                            color: Hs.red,
                          ),
                          onPressed: () => _delete(l),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          if (footerTotal > 0) footerBar(),
        ],
      ),
    );
  }
}
