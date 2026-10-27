// lib/features/users/user_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';

class UserRow {
  UserRow(this.raw);
  final Map<String, dynamic> raw;

  /// The datatable fills every empty column with a literal "-"; treat that as
  /// empty so the UI can hide it instead of showing a stray dash.
  static String _text(Object? v) {
    final s = (v ?? '').toString().trim();
    return s == '-' ? '' : s;
  }

  int get id => asInt(raw['ID']) ?? 0;
  String get firstName => _text(raw['FirstName']);
  String get lastName => _text(raw['LastName']);
  String get name => '$firstName $lastName'.trim();
  String get email => _text(raw['EmailID']);
  String get mobile => _text(raw['MobileNo']);
  int get role => asInt(raw['user_role']) ?? 0;
  bool get isAdmin => role == 1;
  String get roleLabel =>
      (raw['Role'] ?? (isAdmin ? 'Admin' : 'User')).toString();
  String? get image => profileImageUrl(raw['profileImage']);

  /// True when every word in [tokens] (already lower-case) appears somewhere
  /// in the name, mobile number, email or role.
  bool matches(List<String> tokens) {
    final haystack = '$name $mobile $email $roleLabel'.toLowerCase();
    return tokens.every(haystack.contains);
  }

  factory UserRow.fromJson(Map<String, dynamic> j) => UserRow(j);
}

/// What the User form lets an admin grant: dashboard modules (with their
/// optional per-module fields) and locations.
class AccessOptions {
  AccessOptions(this.modules, this.locations);
  final List<AccessModule> modules;
  final List<AccessLocation> locations;
}

class AccessModule {
  AccessModule(this.slug, this.label, this.fields);
  final String slug;
  final String label;
  final List<({String key, String label})> fields;
}

class AccessLocation {
  AccessLocation(this.id, this.name, this.code);
  final int id;
  final String name;
  final String code;
}

/// One user's grants, as edited on the form.
///
/// Location access is PER MODULE ([moduleLocations]: module slug -> location
/// ids): inside a module the user only sees that module's locations, and a
/// ticked module with none shows no data.
class AccessSelection {
  AccessSelection({
    Set<String>? modules,
    Map<String, Set<String>>? fields,
    Map<String, Set<int>>? moduleLocations,
  })  : modules = modules ?? {},
        fields = fields ?? {},
        moduleLocations = moduleLocations ?? {};

  final Set<String> modules;
  final Map<String, Set<String>> fields;
  final Map<String, Set<int>> moduleLocations;

  /// From `access` in GET /users/{id}.
  ///
  /// `access.module_locations` is the new per-module list. `access.locations`
  /// is the OLD global list that used to apply to every module; the server
  /// can no longer save it, so (like the web form) it is folded into each
  /// module's own list here — saving then migrates it instead of dropping it.
  factory AccessSelection.fromJson(Object? j) {
    if (j is! Map) return AccessSelection();
    final f = j['fields'];
    final ml = j['module_locations'];
    Set<int> ids(Object? v) => {
          for (final x in (v as List?) ?? const [])
            if (asInt(x) != null) asInt(x)!,
        };

    final legacy = ids(j['locations']);
    final modules =
        ((j['modules'] as List?) ?? const []).map((e) => '$e').toSet();
    return AccessSelection(
      modules: modules,
      fields: {
        if (f is Map)
          for (final e in f.entries)
            '${e.key}': ((e.value as List?) ?? const []).map((x) => '$x').toSet(),
      },
      moduleLocations: {
        for (final m in modules)
          m: {
            ...ids(ml is Map ? ml[m] : null),
            ...legacy,
          },
      },
    );
  }
}

final userRepositoryProvider = Provider((ref) => UserRepository(ref));

class UserRepository {
  UserRepository(this.ref);
  final Ref ref;

  /// The server caps one datatable request at 100 rows.
  static const _batch = 100;

  Future<PagedResponse<UserRow>> _fetch(int page, int perPage) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/users/datatable',
          page: page,
          perPage: perPage,
        );
    return PagedResponse.parse(body, UserRow.fromJson,
        page: page, perPage: perPage);
  }

  /// The user list, with a search done HERE rather than by the server: the
  /// server only LIKE-matches FirstName, LastName and EmailID one by one, so a
  /// full name ("Renu Chopra"), a mobile number or a role ("admin") — all of
  /// which the search box promises — would find nothing. A search therefore
  /// loads every user (there are only a handful) and filters them.
  Future<PagedResponse<UserRow>> list(int page, String search) async {
    final words = search.trim().toLowerCase().split(RegExp(r'\s+'));
    if (words.length == 1 && words.single.isEmpty) {
      return _fetch(page, AppConfig.pageSize);
    }

    final all = <UserRow>[];
    for (var p = 1; p <= 50; p++) {
      final res = await _fetch(p, _batch);
      all.addAll(res.items);
      if (!res.meta.hasMore || res.items.isEmpty) break;
    }
    final hits = [
      for (final u in all)
        if (u.matches(words)) u,
    ];

    const size = AppConfig.pageSize;
    return PagedResponse(
      items: hits.skip((page - 1) * size).take(size).toList(),
      meta: PageMeta(
        page: page,
        perPage: size,
        total: hits.length,
        lastPage: hits.isEmpty ? 1 : (hits.length / size).ceil(),
      ),
    );
  }

  /// GET /users/access-options -> modules (+ fields) and locations.
  Future<AccessOptions> accessOptions() async {
    final data = await ref.read(apiClientProvider).getData('/users/access-options');
    final m = (data as Map?) ?? const {};
    return AccessOptions(
      [
        for (final e in (m['modules'] as List? ?? const []).whereType<Map>())
          AccessModule(
            '${e['slug']}',
            '${e['label'] ?? e['slug']}',
            [
              for (final f in (e['fields'] as List? ?? const []).whereType<Map>())
                (key: '${f['key']}', label: '${f['label'] ?? f['key']}'),
            ],
          ),
      ],
      [
        for (final e in (m['locations'] as List? ?? const []).whereType<Map>())
          if (asInt(e['id']) != null)
            AccessLocation(asInt(e['id'])!, '${e['name'] ?? ''}', '${e['code'] ?? ''}'),
      ],
    );
  }

  Future<Map<String, dynamic>> getUser(int id) async {
    final data = await ref.read(apiClientProvider).getData('/users/$id');
    return (data as Map).cast<String, dynamic>();
  }

  /// Every DB table the admin is allowed to grant field-level view
  /// permissions on (GET /users/permission-tables).
  Future<List<String>> permissionTables() async {
    final data =
        await ref.read(apiClientProvider).getData('/users/permission-tables');
    return ((data as List?) ?? const []).map((e) => '$e').toList();
  }

  /// Every column of one [table] (GET /users/table-fields) — the response
  /// puts the list under a top-level `fields` key, not `data`.
  Future<List<String>> tableFields(String table) async {
    final body = await ref
        .read(apiClientProvider)
        .getRaw('/users/table-fields', query: {'table': table});
    return ((body['fields'] as List?) ?? const []).map((e) => '$e').toList();
  }

  /// A non-admin user's saved field permissions, as `{table: [fields]}`.
  /// Admins always get `{}` back (the backend grants them every field).
  Future<Map<String, List<String>>> userFieldPermissions(int userId) async {
    final data = await ref
        .read(apiClientProvider)
        .getData('/users/$userId/field-permissions');
    if (data is! Map) return {};
    return data.map(
      (k, v) => MapEntry(
        '$k',
        ((v as List?) ?? const []).map((e) => '$e').toList(),
      ),
    );
  }

  /// Create ([id] == null) or update. [imagePath] optional on edit,
  /// required by the API on create. [access] (modules / module fields /
  /// locations) is only sent for role `0` (User).
  Future<void> save({
    int? id,
    required String firstName,
    required String lastName,
    required String mobile,
    required String email,
    required int role,
    String? imagePath,
    AccessSelection? access,
  }) async {
    final fields = <String, dynamic>{
      'FirstName': firstName,
      'LastName': lastName,
      // Login is mobile number + OTP now, and the number must be unique —
      // the server rejects a number another user already has.
      'MobileNo': mobile,
      // Email is optional on the backend now — omit the key entirely when
      // blank rather than sending an empty string, so its `nullable|email`
      // rule doesn't reject an empty value as a badly-formed one.
      'EmailID': ?(email.isEmpty ? null : email),
      'user_role': role,
      'IsActive': 1,
      'ID': ?id,
    };
    // Admins always have full access, so their grants are left untouched.
    // `access_submitted` tells the backend to replace the stored grants —
    // that is how un-ticking everything is saved.
    if (role == 0 && access != null) {
      fields['access_submitted'] = 1;
      fields['access_modules'] = access.modules.toList();
      fields['access_fields'] = {
        for (final e in access.fields.entries)
          if (access.modules.contains(e.key) && e.value.isNotEmpty)
            e.key: e.value.toList(),
      };
      // Locations are per module now (`access_locations[]` is ignored by the
      // server): only ticked modules are sent, each with its own list.
      fields['access_module_locations'] = {
        for (final m in access.modules)
          if ((access.moduleLocations[m] ?? const <int>{}).isNotEmpty)
            m: access.moduleLocations[m]!.map((e) => '$e').toList(),
      };
    }
    await ref.read(apiClientProvider).postForm(
          '/users/save',
          fields: fields,
          filePath: imagePath,
          fileField: 'profileImage',
        );
  }

  Future<void> delete(int id) async {
    await ref.read(apiClientProvider).deleteRaw('/users/$id');
  }
}
