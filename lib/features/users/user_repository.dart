// lib/features/users/user_repository.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../core/paged_response.dart';
import '../../core/providers.dart';

class UserRow {
  UserRow(this.raw);
  final Map<String, dynamic> raw;

  int get id => asInt(raw['ID']) ?? 0;
  String get firstName => (raw['FirstName'] ?? '').toString();
  String get lastName => (raw['LastName'] ?? '').toString();
  String get name => '$firstName $lastName'.trim();
  String get email => (raw['EmailID'] ?? '').toString();
  int get role => asInt(raw['user_role']) ?? 0;
  bool get isAdmin => role == 1;
  String get roleLabel =>
      (raw['Role'] ?? (isAdmin ? 'Admin' : 'User')).toString();
  String? get image => profileImageUrl(raw['profileImage']);

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
class AccessSelection {
  AccessSelection({
    Set<String>? modules,
    Map<String, Set<String>>? fields,
    Set<int>? locations,
  })  : modules = modules ?? {},
        fields = fields ?? {},
        locations = locations ?? {};

  final Set<String> modules;
  final Map<String, Set<String>> fields;
  final Set<int> locations;

  /// From `access` in GET /users/{id}.
  factory AccessSelection.fromJson(Object? j) {
    if (j is! Map) return AccessSelection();
    final f = j['fields'];
    return AccessSelection(
      modules: ((j['modules'] as List?) ?? const []).map((e) => '$e').toSet(),
      fields: {
        if (f is Map)
          for (final e in f.entries)
            '${e.key}': ((e.value as List?) ?? const []).map((x) => '$x').toSet(),
      },
      locations: {
        for (final v in (j['locations'] as List?) ?? const [])
          if (asInt(v) != null) asInt(v)!,
      },
    );
  }
}

final userRepositoryProvider = Provider((ref) => UserRepository(ref));

class UserRepository {
  UserRepository(this.ref);
  final Ref ref;

  Future<PagedResponse<UserRow>> list(int page, String search) async {
    final body = await ref.read(apiClientProvider).listRaw(
          '/users/datatable',
          page: page,
          perPage: AppConfig.pageSize,
          search: search,
        );
    return PagedResponse.parse(body, UserRow.fromJson,
        page: page, perPage: AppConfig.pageSize);
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
    required String email,
    required int role,
    String? password,
    String? imagePath,
    AccessSelection? access,
  }) async {
    final fields = <String, dynamic>{
      'FirstName': firstName,
      'LastName': lastName,
      'EmailID': email,
      'user_role': role,
      'IsActive': 1,
      'ID': ?id,
    };
    if ((password ?? '').isNotEmpty) fields['Pwd'] = password;
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
      fields['access_locations'] = access.locations.map((e) => '$e').toList();
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
