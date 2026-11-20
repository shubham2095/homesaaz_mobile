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
  _FakeApi({this.empty = false, this.noVacant = false});

  /// Answer like a database with no rows (Pearl Stay has no data yet).
  final bool empty;

  /// Leave `Vacant` out, so the app must work it out (Total Bed - Let Out).
  final bool noVacant;
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
    if (empty) {
      return {'draw': 1, 'recordsTotal': 0, 'recordsFiltered': 0, 'data': []};
    }
    final row = <String, dynamic>{
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
    };
    if (noVacant) row.remove('Vacant');
    return {
      'draw': 1,
      'recordsTotal': 1,
      'recordsFiltered': 1,
      'data': [row],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeApi> _show(WidgetTester tester, Widget screen,
    {bool empty = false, bool noVacant = false, bool wide = false}) async {
  final api = _FakeApi(empty: empty, noVacant: noVacant);
  if (wide) {
    // Wider than the whole table, so the Action column is on screen to tap.
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
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
      // First and last name are separate columns here, like the web.
      expect(find.text('ASHA'), findsOneWidget);
      expect(find.text('VERMA'), findsOneWidget);
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

  group('tables, like the web list pages', () {
    // Header labels in the web's order — S.No first, Action last.
    const headers = <String, List<String>>{
      'pending': ['S.No', 'Student Name', 'Room No', 'Location', 'Rent Amount',
        'Rec Amount', 'Bal Amount', 'Rent Date', 'Action'],
      'students': ['S.No', 'Student Name', 'Father Name', 'Mobile No', 'Room No',
        'Location', 'Rent Amount', 'Rent Date', 'Action'],
      'beds': ['S.No', 'Location Name', 'Total Bed', 'Vacant', 'Let Out', 'Action'],
      'new': ['S.No', 'First Name', 'Last Name', 'Mobile No', 'Aadhaar Card',
        'Location', 'Father Name', 'Action'],
    };
    final screens = <String, Widget>{
      'pending': const PendingRentScreen(stay: Stay.pearl),
      'students': const StudentListScreen(stay: Stay.pearl),
      'beds': const BedOccupancyScreen(stay: Stay.pearl),
      'new': const NewStudentListScreen(stay: Stay.pearl),
    };

    for (final name in headers.keys) {
      testWidgets('$name: header row, S.No and an eye button per row',
          (tester) async {
        await _show(tester, screens[name]!);
        for (final h in headers[name]!) {
          expect(find.text(h), findsWidgets, reason: 'column "$h"');
        }
        expect(find.text('1'), findsOneWidget); // S.No of the single row
        expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
        expect(find.textContaining('Showing 1 to 1 of 1'), findsOneWidget);
      });

      testWidgets('$name: with no data the header stays, with a message',
          (tester) async {
        await _show(tester, screens[name]!, empty: true);
        for (final h in headers[name]!) {
          expect(find.text(h), findsWidgets, reason: 'column "$h"');
        }
        expect(find.textContaining('data found'), findsOneWidget);
        expect(find.byIcon(Icons.visibility_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('amounts print with paise and Indian grouping', (tester) async {
      await _show(tester, const PendingRentScreen(stay: Stay.pearl));
      expect(find.text('₹6,500.00'), findsOneWidget); // rent
      expect(find.text('₹2,000.00'), findsOneWidget); // received
      expect(find.text('₹4,500.00'), findsOneWidget); // balance
    });

    testWidgets('the eye button opens the record\'s details', (tester) async {
      await _show(tester, const StudentListScreen(stay: Stay.pearl), wide: true);
      // The detail sheet's labels are upper-cased by HsRow.
      expect(find.text('ADDRESS'), findsNothing);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.text('ADDRESS'), findsOneWidget);
      expect(find.text('STARTING DATE'), findsOneWidget);
      expect(find.text('ASHA VERMA'), findsNWidgets(2)); // row + sheet title
    });

    testWidgets('tapping the row itself also opens the details', (tester) async {
      await _show(tester, const PendingRentScreen(stay: Stay.pearl));
      await tester.tap(find.text('ASHA VERMA'));
      await tester.pumpAndSettle();
      expect(find.text('ASHA VERMA'), findsNWidgets(2)); // row + sheet title
      expect(find.text('Bal Amount'), findsOneWidget); // the column header
      expect(find.text('BAL AMOUNT'), findsOneWidget); // the sheet's row
    });

    testWidgets('bed occupancy: vacant is Total Bed - Let Out when the API omits it',
        (tester) async {
      await _show(tester, const BedOccupancyScreen(stay: Stay.pearl),
          noVacant: true, wide: true);
      expect(find.text('6'), findsOneWidget); // 20 beds - 14 let out
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(find.text('TOTAL BED'), findsOneWidget); // the sheet's row
      expect(find.text('6'), findsNWidgets(2)); // cell + sheet
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
