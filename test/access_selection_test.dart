import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/features/users/user_repository.dart';

void main() {
  test('per-module locations are read per ticked module', () {
    final s = AccessSelection.fromJson({
      'modules': ['grn', 'item-stock'],
      'fields': <String, dynamic>{},
      'locations': <int>[],
      'module_locations': {
        'grn': [8, 26],
        'item-stock': [29],
        'attendance': [8], // not ticked -> ignored
      },
    });
    expect(s.moduleLocations['grn'], {8, 26});
    expect(s.moduleLocations['item-stock'], {29});
    expect(s.moduleLocations.containsKey('attendance'), isFalse);
  });

  test('old global locations are folded into every ticked module', () {
    final s = AccessSelection.fromJson({
      'modules': ['grn', 'item-stock'],
      'locations': [26],
      'module_locations': {
        'grn': [8],
      },
    });
    expect(s.moduleLocations['grn'], {8, 26});
    expect(s.moduleLocations['item-stock'], {26});
  });

  test('a user with no access reads as empty (and an empty-list '
      'module_locations does not crash)', () {
    final s = AccessSelection.fromJson({
      'modules': ['grn'],
      'locations': <int>[],
      'module_locations': <dynamic>[],
    });
    expect(s.moduleLocations['grn'], isEmpty);
    expect(AccessSelection.fromJson(null).modules, isEmpty);
  });
}
