// lib/features/students/student_list_screen.dart
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
    Provider.family<_StudentRepo, Stay>((ref, stay) => _StudentRepo(ref, stay));

class _StudentRepo {
  _StudentRepo(this.ref, this.stay);
  final Ref ref;
  final Stay stay;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '${stay.apiBase}/student-details/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

/// Column order mirrors web `studentDetails/list.blade.php`'s `<thead>` (S.No
/// and Action are added by [StayTableScreen]).
const _columns = <HsTableColumn>[
  HsTableColumn('Student Name', width: 180),
  HsTableColumn('Father Name', width: 170),
  HsTableColumn('Mobile No', width: 120),
  HsTableColumn('Room No', width: 90),
  HsTableColumn('Location', width: 120),
  HsTableColumn('Rent Amount', width: 120, alignEnd: true),
  HsTableColumn('Rent Date', width: 110),
];

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key, this.stay = Stay.home});

  /// Which hostel's data: ALFOHOMES (default) or Pearl Stay.
  final Stay stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider(stay));
    return StayTableScreen(
      title: 'Student Details',
      searchHint: 'Student name, room no or location…',
      emptyMessage: 'No student data found',
      columns: _columns,
      fetchPage: repo.list,
      cells: (m) => [
        stayName(m['StudentName']),
        Text(orDash(m['FatherName'])),
        Text(orDash(m['MobileNo'])),
        Text(orDash(m['RoomNo'])),
        Text(orDash(m['Location'])),
        Text(money2(m['RentAmt'])),
        Text(prettyDate(m['RentDate'])),
      ],
      detailTitle: (m) => orDash(m['StudentName']),
      detailRows: (m) => [
        ('Room No', orDash(m['RoomNo'])),
        ('Bed No', orDash(m['BedNo'])),
        ('Location', orDash(m['Location'])),
        ('Rent Amount', money2(m['RentAmt'])),
        ('Rent Date', prettyDate(m['RentDate'])),
        ('Mobile No', orDash(m['MobileNo'])),
        ('Father Name', orDash(m['FatherName'])),
        ('Address', orDash(m['address'])),
        ('Starting Date', prettyDate(m['StartingDate'])),
        ('Ending Date', prettyDate(m['EndingDate'])),
      ],
    );
  }
}
