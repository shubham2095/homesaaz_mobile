import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:homesaaz_mobile/core/api_client.dart';
import 'package:homesaaz_mobile/core/config.dart';
import 'package:homesaaz_mobile/core/providers.dart';
import 'package:homesaaz_mobile/features/users/user_repository.dart';

/// Stands in for the server's `/users/datatable`: pages the rows, caps a
/// request at 100 like the real controller, fills empty columns with "-", and
/// — like the real one — knows nothing about full names, mobiles or roles.
class _FakeApi implements ApiClient {
  _FakeApi(this.users);
  final List<Map<String, dynamic>> users;
  final requests = <({int page, int perPage, String search})>[];

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
    requests.add((page: page, perPage: perPage, search: search));
    final size = perPage.clamp(1, 100);
    return {
      'data': users.skip((page - 1) * size).take(size).toList(),
      'recordsFiltered': users.length,
      'recordsTotal': users.length,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _user(int id, String first, String last,
        {String mobile = '-', String email = '-', int role = 0}) =>
    {
      'ID': id,
      'FirstName': first,
      'LastName': last,
      'MobileNo': mobile,
      'EmailID': email,
      'user_role': role,
      'Role': role == 1 ? 'Admin' : 'User',
    };

void main() {
  final people = [
    _user(1, 'RENU', 'CHOPRA', mobile: '9871188887'),
    _user(2, 'Shubham', 'Shubham', mobile: '9891508808', role: 1),
    _user(3, 'Vivek', 'NAGARIYA', mobile: '9717296096', email: 'vivek@homesaaz.in', role: 1),
  ];

  (UserRepository, _FakeApi) setup(List<Map<String, dynamic>> rows) {
    final api = _FakeApi(rows);
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(c.dispose);
    return (c.read(userRepositoryProvider), api);
  }

  Future<List<int>> ids(UserRepository repo, String q, [int page = 1]) async =>
      [for (final u in (await repo.list(page, q)).items) u.id];

  test('no search: a plain server page, no search sent', () async {
    final (repo, api) = setup(people);
    expect(await ids(repo, ''), [1, 2, 3]);
    expect(await ids(repo, '   '), [1, 2, 3]);
    expect(api.requests.first.perPage, AppConfig.pageSize);
    expect(api.requests.every((r) => r.search.isEmpty), isTrue);
  });

  test('a full name finds the user (the server matches first OR last only)',
      () async {
    final (repo, _) = setup(people);
    expect(await ids(repo, 'renu chopra'), [1]);
    expect(await ids(repo, 'CHOPRA renu'), [1]); // any order, any case
    expect(await ids(repo, 'vivek nag'), [3]);
  });

  test('mobile number, partial number and email are searchable', () async {
    final (repo, _) = setup(people);
    expect(await ids(repo, '9891508808'), [2]);
    expect(await ids(repo, '97172'), [3]);
    expect(await ids(repo, 'homesaaz.in'), [3]);
  });

  test('role is searchable, as the hint promises', () async {
    final (repo, _) = setup(people);
    expect(await ids(repo, 'admin'), [2, 3]);
    expect(await ids(repo, 'user'), [1]);
  });

  test('no match -> empty result, one page', () async {
    final (repo, _) = setup(people);
    final res = await repo.list(1, 'zzz');
    expect(res.items, isEmpty);
    expect(res.meta.total, 0);
    expect(res.meta.hasMore, isFalse);
  });

  test('the "-" the server puts in empty columns is treated as empty', () {
    final u = UserRow(_user(9, '-', 'X'));
    expect(u.firstName, '');
    expect(u.name, 'X');
    expect(u.email, '');
    expect(u.mobile, '');
    expect(u.matches(['-']), isFalse);
  });

  test('more users than one request: loads every batch, then pages the hits',
      () async {
    final many = [
      for (var i = 1; i <= 250; i++) _user(i, 'Staff', 'Member$i'),
    ];
    final (repo, api) = setup(many);

    final first = await repo.list(1, 'staff');
    expect(first.items.length, AppConfig.pageSize);
    expect(first.meta.total, 250);
    expect(first.meta.hasMore, isTrue);
    expect(api.requests.map((r) => r.perPage).toSet(), {100});
    expect(api.requests.length, 3); // 100 + 100 + 50

    final last = await repo.list(13, 'staff'); // 250 / 20 -> 13 pages
    expect(last.items.length, 10);
    expect(last.meta.hasMore, isFalse);
    expect(await ids(repo, 'member250'), [250]);
  });
}
