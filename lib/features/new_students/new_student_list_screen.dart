// lib/features/new_students/new_student_list_screen.dart
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

final _repoProvider = Provider((ref) => _NewStudentRepo(ref));

class _NewStudentRepo {
  _NewStudentRepo(this.ref);
  final Ref ref;

  Future<PagedResponse<Map<String, dynamic>>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/homestay/new-student/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, (j) => j,
        page: page, perPage: AppConfig.pageSize);
  }
}

class NewStudentListScreen extends ConsumerWidget {
  const NewStudentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(_repoProvider);
    return Scaffold(
      drawer: const HsDrawer(),
      appBar: const HsAppBar(title: 'Student New Admission'),
      body: PagedListView<Map<String, dynamic>>(
        searchHint: 'Name, mobile or location…',
        fetchPage: repo.list,
        itemBuilder: (context, m) {
          final name =
              '${orDash(m['FirstName'])} ${m['LastName'] ?? ''}'.trim();
          return HsListCard(
            onTap: () => _showDetail(context, m, name),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Hs.ink)),
                const SizedBox(height: 6),
                HsRow('Mobile No', orDash(m['MobileNo']), bottomDivider: true),
                HsRow('Aadhaar', orDash(m['Addarcard']), bottomDivider: true),
                HsRow('Location', orDash(m['Location']), bottomDivider: true),
                HsRow('Father Name', orDash(m['FatherName'])),
              ],
            ),
          );
        },
      ),
    );
  }
}

void _showDetail(BuildContext context, Map<String, dynamic> m, String name) {
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
            Text(name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            HsRow('Mobile No', orDash(m['MobileNo'])),
            HsRow('Aadhaar Card', orDash(m['Addarcard'])),
            HsRow('Vaccination', orDash(m['Vaccination'])),
            HsRow('Location', orDash(m['Location'])),
            HsRow('Father Name', orDash(m['FatherName'])),
            HsRow('Father Mobile', orDash(m['FatherMobileNo'])),
            HsRow('Mother Name', orDash(m['MotherName'])),
            HsRow('Mother Mobile', orDash(m['MotherMobileNo'])),
            HsRow('Remarks', orDash(m['Remarks'])),
            HsRow('Transferred', '${m['TrfToMain'] ?? '-'}'),
          ],
        ),
      ),
    ),
  );
}
