import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/core/api_client.dart';
import 'package:homesaaz_mobile/core/providers.dart';
import 'package:homesaaz_mobile/features/bed_occupancy/bed_occupancy_screen.dart';
import 'package:homesaaz_mobile/features/home_stay/home_stay_screen.dart';
import 'package:homesaaz_mobile/features/home_stay/stay.dart';
import 'package:homesaaz_mobile/features/new_students/new_student_list_screen.dart';
import 'package:homesaaz_mobile/features/pending_rent/pending_rent_screen.dart';
import 'package:homesaaz_mobile/features/students/student_list_screen.dart';

/// Records which endpoint each screen asks for and answers with one row, in the
/// shape the Pearl / Home Stay datatable endpoints return.
class _FakeApi implements ApiClient {
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> listRaw(
    String path, {
    required int page,
    required int perPage,
    String search = '',
    bool dataTableSearch = true,
    bool logoutOn401 = true,
    Map<String, dynamic>? extra,
  }) async {
    paths.add(path);
    return {
      'draw': 1,
      'recordsTotal': 1,
      'recordsFiltered': 1,
      'data': [
        {
          'Name': 'ASHA VERMA',
          'StudentName': 'ASHA VERMA',
          'FirstName': 'ASHA',
          'LastName': 'VERMA',
          'LocationName': 'PEARL HOSTEL',
          'Location': 'PEARL HOSTEL',
          'RoomNo': '12',
          'BedNo': 'B',
          'RentAmount': 6500,
          'RentAmt': 6500,
          'RecAmount': 2000,
          'BalAmount': 4500,
          'MobileNo': '9811122233',
          'FatherName': 'RAMESH VERMA',
          'TOTALBED': 20,
          'Letout': 14,
          'Vacant': 6,
        },
      ],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeApi> _show(WidgetTester tester, Widget screen) async {
  final api = _FakeApi();
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(api)],
    child: MaterialApp(home: screen),
  ));
  // PagedListView loads in initState; HsAppear fades rows in on a timer.
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
  return api;
}

void main() {
  group('Stay', () {
    test('Pearl routes and API prefix differ from ALFOHOMES, nothing overlaps', () {
      expect(Stay.home.apiBase, '/homestay');
      expect(Stay.pearl.apiBase, '/pearlstay');
      final routes = [
        for (final s in Stay.values) ...[
          s.hubRoute,
          s.pendingRentRoute,
          s.studentsRoute,
          s.bedOccupancyRoute,
          s.newStudentsRoute,
        ],
      ];
      expect(routes.toSet().length, routes.length);
      expect(Stay.pearl.hubRoute, '/pearl-stay');
    });
  });

  group('each Pearl screen calls the /pearlstay endpoint', () {
    testWidgets('Pending Rent', (tester) async {
      final api = await _show(tester, const PendingRentScreen(stay: Stay.pearl));
      expect(api.paths, ['/pearlstay/pending-rent/datatable']);
      expect(find.text('ASHA VERMA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Student Details', (tester) async {
      final api = await _show(tester, const StudentListScreen(stay: Stay.pearl));
      expect(api.paths, ['/pearlstay/student-details/datatable']);
      expect(find.text('ASHA VERMA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Bed Occupancy', (tester) async {
      final api = await _show(tester, const BedOccupancyScreen(stay: Stay.pearl));
      expect(api.paths, ['/pearlstay/bed-occupancy/datatable']);
      expect(find.text('PEARL HOSTEL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('New Student', (tester) async {
      final api =
          await _show(tester, const NewStudentListScreen(stay: Stay.pearl));
      expect(api.paths, ['/pearlstay/new-student/datatable']);
      expect(find.text('ASHA VERMA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ALFOHOMES is unchanged (defaults to /homestay)', () {
    testWidgets('all four screens', (tester) async {
      for (final screen in const <Widget>[
        PendingRentScreen(),
        StudentListScreen(),
        BedOccupancyScreen(),
        NewStudentListScreen(),
      ]) {
        final api = await _show(tester, screen);
        expect(api.paths.single, startsWith('/homestay/'));
      }
    });
  });

  group('hub', () {
    testWidgets('Pearl hub shows the web Pearl names, ALFOHOMES its own',
        (tester) async {
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: StayHubScreen(stay: Stay.pearl)),
      ));
      await tester.pump();
      expect(find.text('PEARL STAY'), findsOneWidget);
      for (final t in ['PENDING RENT', 'STUDENT DETAILS', 'BED STATUS', 'NEW STUDENT']) {
        expect(find.text(t), findsOneWidget);
      }

      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: StayHubScreen()),
      ));
      await tester.pump();
      expect(find.text('ALFOHOMES'), findsOneWidget);
      expect(find.text('BED OCCUPANCY'), findsOneWidget);
    });
  });
}
