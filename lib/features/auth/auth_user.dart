// lib/features/auth/auth_user.dart

/// Works with both shapes the API returns:
///   * POST /auth/login  -> { id, firstname, lastname, email, role }
///   * GET  /auth/me      -> { ID, FirstName, LastName, EmailID, user_role, IsActive }
class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.profileImage,
  });

  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final int role;

  /// Bare path from the server (e.g. `uploads/users/x.jpg`), if any.
  final String? profileImage;

  bool get isAdmin => role == 1;
  String get fullName => '$firstName $lastName'.trim();

  factory AuthUser.fromJson(Map<String, dynamic> j) {
    T? pick<T>(List<String> keys) {
      for (final k in keys) {
        if (j[k] != null) return j[k] as T;
      }
      return null;
    }

    int asInt(Object? v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;

    return AuthUser(
      id: asInt(pick<Object?>(['id', 'ID'])),
      firstName: '${pick<Object?>(['firstname', 'FirstName']) ?? ''}',
      lastName: '${pick<Object?>(['lastname', 'LastName']) ?? ''}',
      email: '${pick<Object?>(['email', 'EmailID']) ?? ''}',
      role: asInt(pick<Object?>(['role', 'user_role']) ?? 0),
      profileImage: pick<Object?>(['profileImage'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstname': firstName,
        'lastname': lastName,
        'email': email,
        'role': role,
        'profileImage': profileImage,
      };
}
