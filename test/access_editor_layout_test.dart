import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/features/users/access_editor.dart';
import 'package:homesaaz_mobile/features/users/user_repository.dart';

class _FakeRepo extends UserRepository {
  _FakeRepo(super.ref);

  @override
  Future<AccessOptions> accessOptions() async => AccessOptions(
        [
          AccessModule('attendance', 'ATTENDANCE', const []),
          AccessModule('document-download', 'DOCUMENT DOWNLOAD', const []),
          AccessModule('upload-gate-entry-bill', 'UPLOAD GATE ENTRY BILL', const []),
          AccessModule('item-stock', 'ITEM STOCK', [
            (key: 'mrp', label: 'MRP'),
            (key: 'supplier_name', label: 'Supplier Name'),
          ]),
        ],
        [
          AccessLocation(1, '37 AVENUE', 'H-37'),
          AccessLocation(2, 'AVENUE WAREHOUSE (BHIWANDI GODOWN)', 'AWH'),
          AccessLocation(3, 'HOMESAAZ BUILDING PLOT', ''),
          AccessLocation(4, 'LS', 'LS-1'),
        ],
      );
}

/// `flutter test` draws text in the Ahem font (every glyph a full-em square),
/// far wider than a phone's Roboto, so overflow checks need the real font.
Future<void> _loadRoboto() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final loader = FontLoader('Roboto');
  for (final f in ['regular', 'medium', 'bold', 'black']) {
    final file = File('$root/bin/cache/artifacts/material_fonts/roboto-$f.ttf');
    if (file.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
    }
  }
  await loader.load();
}

void main() {
  setUpAll(_loadRoboto);

  Future<void> pump(WidgetTester tester, AccessSelection sel, double width) async {
    tester.view.physicalSize = Size(width * 3, 2400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWith((ref) => _FakeRepo(ref)),
      ],
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Roboto'),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AccessEditor(selection: sel),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final w in [320.0, 360.0, 411.0]) {
    testWidgets('lays out without overflow at ${w.toInt()}px wide',
        (tester) async {
      final sel = AccessSelection(
        modules: {'attendance', 'item-stock', 'upload-gate-entry-bill'},
        fields: {'item-stock': {'mrp'}},
        moduleLocations: {
          'attendance': {1, 2},
        },
      );
      await pump(tester, sel, w);
      expect(tester.takeException(), isNull);
      expect(find.text('Module Access'), findsOneWidget);
      expect(find.text('ITEM STOCK - Field Access'), findsOneWidget);
      expect(find.text('ATTENDANCE - Locations'), findsOneWidget);
      expect(find.text('Selected: 3 module(s), 2 location(s).'), findsOneWidget);
    });
  }

  testWidgets('a location card with picks starts collapsed and opens on tap',
      (tester) async {
    final sel = AccessSelection(
      modules: {'attendance'},
      moduleLocations: {
        'attendance': {1, 2},
      },
    );
    await pump(tester, sel, 360);

    // Collapsed: the picked names are summarised and no tiles are built.
    expect(find.text('37 AVENUE, AVENUE WAREHOUSE (BHIWANDI GODOWN)'),
        findsOneWidget);
    expect(find.textContaining('HOMESAAZ BUILDING PLOT'), findsNothing);

    await tester.tap(find.text('ATTENDANCE - Locations'));
    await tester.pump();
    expect(find.textContaining('HOMESAAZ BUILDING PLOT'), findsOneWidget);
    expect(sel.moduleLocations['attendance'], {1, 2}); // opening edits nothing
  });

  testWidgets('tapping a tile and Select All still edit the selection',
      (tester) async {
    final sel = AccessSelection(
      modules: {'attendance'},
      moduleLocations: {'attendance': <int>{}},
    );
    await pump(tester, sel, 360);

    // Empty -> amber note is shown.
    expect(find.textContaining('No location selected'), findsOneWidget);

    // The location label is a Text.rich (name + code), so match rich text.
    await tester.tap(find.textContaining('37 AVENUE', findRichText: true));
    await tester.pump();
    expect(sel.moduleLocations['attendance'], {1});
    expect(find.textContaining('No location selected'), findsNothing);

    // The location card's "Select All" is the second one (modules card is first).
    await tester.tap(find.text('Select All').at(1));
    await tester.pump();
    expect(sel.moduleLocations['attendance'], {1, 2, 3, 4});

    await tester.tap(find.text('Select All').at(1));
    await tester.pump();
    expect(sel.moduleLocations['attendance'], isEmpty);

    // Module tile toggles the module.
    await tester.tap(find.text('DOCUMENT DOWNLOAD'));
    await tester.pump();
    expect(sel.modules, contains('document-download'));
  });
}
