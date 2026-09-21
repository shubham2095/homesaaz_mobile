// lib/core/auth_store.dart
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the Sanctum bearer token + the cached user profile in the
/// Android Keystore-backed secure storage.
///
/// The token is also held in memory: `flutter_secure_storage` reads can
/// transiently fail / return null on some Android devices, and a missing
/// `Authorization` header makes the server 401 → the app logs itself out.
/// The in-memory copy makes reads reliable for the life of the process.
class AuthStore {
  static const _kToken = 'token';
  static const _kUser = 'user';

  final FlutterSecureStorage _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _tokenCache;
  bool _tokenLoaded = false;

  Future<void> save(String token, Map<String, dynamic> user) async {
    _tokenCache = token;
    _tokenLoaded = true;
    await _s.write(key: _kToken, value: token);
    await _s.write(key: _kUser, value: jsonEncode(user));
  }

  Future<String?> readToken() async {
    if (_tokenLoaded) return _tokenCache;
    try {
      _tokenCache = await _s.read(key: _kToken);
    } catch (_) {
      _tokenCache = null;
    }
    _tokenLoaded = true;
    return _tokenCache;
  }

  Future<Map<String, dynamic>?> readUser() async {
    try {
      final raw = await _s.read(key: _kUser);
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    _tokenCache = null;
    _tokenLoaded = true;
    await _s.deleteAll();
  }
}
