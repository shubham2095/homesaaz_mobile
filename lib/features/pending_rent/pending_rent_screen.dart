// lib/features/pending_rent/pending_rent_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../../widgets/hs_table.dart';
import '../home_stay/stay.dart';
import '../home_stay/stay_table.dart';

final _repoProvider =
    Provider.family<_PendingRentRepo, Stay>((ref, stay) => _PendingRentRepo(ref, stay));

class _PendingRentRepo {
  _PendingRentRepo(this.ref, this.stay);
  final Ref ref;
  final Stay stay;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '${stay.apiBase}/pending-rent/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

/// Column order mirrors web `pendingRent/list.blade.php`'s `<thead>` (S.No and
/// Action are added by [StayTableScreen]).
const _columns = <HsTableColumn>[
  HsTableColumn('Student Name', width: 180),
  HsTableColumn('Room No', width: 90),
  HsTableColumn('Location', width: 120),
  HsTableColumn('Rent Amount', width: 120, alignEnd: true),
  HsTableColumn('Rec Amount', width: 120, alignEnd: true),
  HsTableColumn('Bal Amount', width: 120, alignEnd: true),
  HsTableColumn('Rent Date', width: 110),
];

class PendingRentScreen extends ConsumerWidget {
  const PendingRentScreen({super.key, this.stay = Stay.home});

  /// Which hostel's data: ALFOHOMES (default) or Pearl Stay.
  final Stay stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider(stay));
    return StayTableScreen(
      title: 'Pending Rent Details',
      searchHint: 'Student name, room no or location…',
      emptyMessage: 'No pending rent data found',
      columns: _columns,
      fetchPage: repo.list,
      cells: (m) => [
        stayName(m['Name']),
        Text(orDash(m['RoomNo'])),
        Text(orDash(m['LocationName'])),
        Text(money2(m['RentAmount'])),
        Text(money2(m['RecAmount'])),
        Text(money2(m['BalAmount']),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(prettyDate(m['RentDate'])),
      ],
      detailTitle: (m) => orDash(m['Name']),
      detailRows: (m) => [
        ('Room No', orDash(m['RoomNo'])),
        ('Location', orDash(m['LocationName'])),
        ('Rent Amount', money2(m['RentAmount'])),
        ('Rec Amount', money2(m['RecAmount'])),
        ('Bal Amount', money2(m['BalAmount'])),
        ('Rent Date', prettyDate(m['RentDate'])),
      ],
    );
  }
}
