// lib/features/new_students/new_student_list_screen.dart
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
    Provider.family<_NewStudentRepo, Stay>((ref, stay) => _NewStudentRepo(ref, stay));

class _NewStudentRepo {
  _NewStudentRepo(this.ref, this.stay);
  final Ref ref;
  final Stay stay;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '${stay.apiBase}/new-student/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

/// Column order mirrors web `newStudent/list.blade.php`'s `<thead>` (S.No and
/// Action are added by [StayTableScreen]).
const _columns = <HsTableColumn>[
  HsTableColumn('First Name', width: 140),
  HsTableColumn('Last Name', width: 140),
  HsTableColumn('Mobile No', width: 120),
  HsTableColumn('Aadhaar Card', width: 150),
  HsTableColumn('Location', width: 120),
  HsTableColumn('Father Name', width: 170),
];

String _fullName(Map<String, dynamic> m) =>
    '${m['FirstName'] ?? ''} ${m['LastName'] ?? ''}'.trim();

class NewStudentListScreen extends ConsumerWidget {
  const NewStudentListScreen({super.key, this.stay = Stay.home});

  /// Which hostel's data: ALFOHOMES (default) or Pearl Stay.
  final Stay stay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider(stay));
    return StayTableScreen(
      title: 'Student New Admission',
      searchHint: 'Name, mobile or location…',
      emptyMessage: 'No admission data found',
      columns: _columns,
      fetchPage: repo.list,
      cells: (m) => [
        stayName(m['FirstName']),
        Text(orDash(m['LastName'])),
        Text(orDash(m['MobileNo'])),
        Text(orDash(m['Addarcard'])),
        Text(orDash(m['Location'])),
        Text(orDash(m['FatherName'])),
      ],
      detailTitle: (m) => _fullName(m).isEmpty ? '-' : _fullName(m),
      detailRows: (m) => [
        ('Mobile No', orDash(m['MobileNo'])),
        ('Aadhaar Card', orDash(m['Addarcard'])),
        ('Vaccination', orDash(m['Vaccination'])),
        ('Location', orDash(m['Location'])),
        ('Father Name', orDash(m['FatherName'])),
        ('Father Mobile', orDash(m['FatherMobileNo'])),
        ('Mother Name', orDash(m['MotherName'])),
        ('Mother Mobile', orDash(m['MotherMobileNo'])),
        ('Remarks', orDash(m['Remarks'])),
        ('Transferred', orDash(m['TrfToMain'])),
      ],
    );
  }
}
