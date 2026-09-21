// lib/features/students/student_list_screen.dart
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

final _repoProvider = Provider((ref) => _StudentRepo(ref));

class _StudentRepo {
  _StudentRepo(this.ref);
  final Ref ref;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/homestay/student-details/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

class StudentListScreen extends ConsumerWidget {
  const StudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Student Details'),
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
                    child: Text(orDash(m['StudentName']),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Hs.ink)),
                  ),
                  Text(money(m['RentAmt']),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Hs.green)),
                ],
              ),
              const SizedBox(height: 6),
              // Order mirrors web's card-row list (studentDetails/list.blade.php
              // renderCards): Name [title], Room, Location, Rent Amount
              // [title trailing], Father Name, Mobile. Web's card does not
              // show Rent Date — dropped here too.
              HsRow('Room / Bed', '${orDash(m['RoomNo'])} · ${orDash(m['BedNo'])}',
                  bottomDivider: true),
              HsRow('Location', orDash(m['Location']), bottomDivider: true),
              HsRow('Father Name', orDash(m['FatherName']), bottomDivider: true),
              HsRow('Mobile No', orDash(m['MobileNo'])),
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
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(orDash(m['StudentName']),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            HsRow('Room No', orDash(m['RoomNo'])),
            HsRow('Bed No', orDash(m['BedNo'])),
            HsRow('Location', orDash(m['Location'])),
            HsRow('Rent Amount', money(m['RentAmt'])),
            HsRow('Rent Date', prettyDate(m['RentDate'])),
            HsRow('Mobile No', orDash(m['MobileNo'])),
            HsRow('Father Name', orDash(m['FatherName'])),
            HsRow('Address', orDash(m['address'])),
            HsRow('Starting Date', prettyDate(m['StartingDate'])),
            HsRow('Ending Date', prettyDate(m['EndingDate'])),
          ],
        ),
      ),
    ),
  );
}
