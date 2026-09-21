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
  String? get image {
    final v = '${raw['profileImage'] ?? ''}';
    return v.startsWith('http') ? v : null;
  }

  factory UserRow.fromJson(Map<String, dynamic> j) => UserRow(j);
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
  /// required by the API on create. [fieldPermissions] is ignored by the
  /// backend for Admin users (they always see every field) — only send it
  /// for role `0` (User).
  Future<void> save({
    int? id,
    required String firstName,
    required String lastName,
    required String email,
    required int role,
    String? password,
    String? imagePath,
    Map<String, List<String>>? fieldPermissions,
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
    if (role == 0 && fieldPermissions != null && fieldPermissions.isNotEmpty) {
      fields['field_permissions'] = fieldPermissions;
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
