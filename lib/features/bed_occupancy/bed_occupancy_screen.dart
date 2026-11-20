// lib/features/bed_occupancy/bed_occupancy_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/tokens.dart';
import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';
import '../../widgets/hs_table.dart';
import '../home_stay/stay.dart';
import '../home_stay/stay_table.dart';

final _repoProvider = Provider.family<_BedOccupancyRepo, Stay>(
    (ref, stay) => _BedOccupancyRepo(ref, stay));

class _BedOccupancyRepo {
  _BedOccupancyRepo(this.ref, this.stay);
  final Ref ref;
  final Stay stay;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '${stay.apiBase}/bed-occupancy/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

/// Column order mirrors web `bedOccupancy/list.blade.php`'s `<thead>` (S.No and
/// Action are added by [StayTableScreen]).
const _columns = <HsTableColumn>[
  HsTableColumn('Location Name', width: 200),
  HsTableColumn('Total Bed', width: 100, alignEnd: true),
  HsTableColumn('Vacant', width: 100, alignEnd: true),
  HsTableColumn('Let Out', width: 100, alignEnd: true),
];

({int total, int vacant, int letout}) _beds(Map<String, dynamic> m) {
  final total = asInt(m['TOTALBED']) ?? 0;
  final letout = asInt(m['Letout']) ?? 0;
  return (total: total, vacant: asInt(m['Vacant']) ?? (total - letout), letout: letout);
}

class BedOccupancyScreen extends ConsumerWidget {
  const BedOccupancyScreen({super.key, this.stay = Stay.home});

  /// Which hostel's data: ALFOHOMES (default) or Pearl Stay.
  final Stay stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider(stay));
    return StayTableScreen(
      title: 'Bed Occupancy',
      searchHint: 'Search by location…',
      emptyMessage: 'No bed occupancy data found',
      columns: _columns,
      fetchPage: repo.list,
      cells: (m) {
        final b = _beds(m);
        return [
          stayName(m['LocationName']),
          Text('${b.total}'),
          // Green while a bed is free, red when the place is full.
          Text('${b.vacant}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: b.vacant > 0 ? Hs.green : Hs.red)),
          Text('${b.letout}'),
        ];
      },
      detailTitle: (m) => orDash(m['LocationName']),
      detailRows: (m) {
        final b = _beds(m);
        return [
          ('Total Bed', '${b.total}'),
          ('Vacant', '${b.vacant}'),
          ('Let Out', '${b.letout}'),
        ];
      },
    );
  }
}
