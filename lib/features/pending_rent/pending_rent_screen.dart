// lib/features/pending_rent/pending_rent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../../widgets/hs_app_bar.dart';
import '../../widgets/hs_drawer.dart';
import '../../widgets/hs_widgets.dart';
import '../../widgets/paged_list_view.dart';

final _repoProvider = Provider((ref) => _PendingRentRepo(ref));

class _PendingRentRepo {
  _PendingRentRepo(this.ref);
  final Ref ref;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/homestay/pending-rent/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

class PendingRentScreen extends ConsumerWidget {
  const PendingRentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Pending Rent Details'),
      body: PagedListView<Map<String, dynamic>>(
        searchHint: 'Student name, room no or location…',
        fetchPage: repo.list,
        itemBuilder: (context, m) => HsListCard(
          onTap: () => _showDetail(context, m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(orDash(m['Name']),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Hs.ink)),
                  ),
                  Text(money(m['BalAmount']),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Hs.red)),
                ],
              ),
              const SizedBox(height: 6),
              // Field order/content mirrors web's card-row list exactly
              // (pendingRent/list.blade.php renderCards): Name [title],
              // Room, Location, Rent, Received, Balance [title trailing].
              // Web's card does NOT show Rent Date — dropped here too.
              HsRow('Room No', orDash(m['RoomNo']), bottomDivider: true),
              HsRow('Location', orDash(m['LocationName']), bottomDivider: true),
              HsRow('Rent Amount', money(m['RentAmount']), bottomDivider: true),
              HsRow('Rec Amount', money(m['RecAmount'])),
            ],
          ),
        ),
      ),
    );
  }
}

void _showDetail(BuildContext context, Map<String, dynamic> m) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(orDash(m['Name']),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          HsRow('Room No', orDash(m['RoomNo'])),
          HsRow('Location', orDash(m['LocationName'])),
          HsRow('Rent Amount', money(m['RentAmount'])),
          HsRow('Rec Amount', money(m['RecAmount'])),
          HsRow('Bal Amount', money(m['BalAmount'])),
          HsRow('Rent Date', prettyDate(m['RentDate'])),
        ],
      ),
    ),
  );
}
