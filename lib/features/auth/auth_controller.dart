// lib/features/auth/auth_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/auth_store.dart';
import '../../core/providers.dart';
import 'auth_user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.user, this.error});

  final AuthStatus status;
  final AuthUser? user;
  final String? error;

  AuthState copyWith({AuthStatus? status, AuthUser? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  static const unknown = AuthState(status: AuthStatus.unknown);
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  AuthStore get _store => ref.read(authStoreProvider);

  @override
  AuthState build() {
    _bootstrap();
    return AuthState.unknown;
  }

  Future<void> _bootstrap() async {
    final token = await _store.readToken();
    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    final cached = await _store.readUser();
    state = AuthState(
      status: AuthStatus.authenticated,
      user: cached != null ? AuthUser.fromJson(cached) : null,
    );
    // best-effort refresh of the profile; ignore failures here
    try {
      final data = await ref.read(apiClientProvider).getData('/auth/me');
      if (data is Map<String, dynamic>) {
        final user = AuthUser.fromJson(data);
        await _store.save(token, user.toJson());
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } on ApiException catch (e) {
      if (e.isAuth) {
        await _store.clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
      }
    }
  }

  bool _busy = false;
  bool get busy => _busy;

  Future<bool> login({
    required String firstname,
    required String password,
    String deviceName = 'android',
  }) async {
    if (_busy) return false;
    _busy = true;
    state = state.copyWith(error: null);
    try {
      // Laravel expects { FirstName, Pwd } and returns token + user at the
      // top level (not wrapped in `data`).
      final body = await ref.read(apiClientProvider).postRaw(
        '/auth/login',
        body: {
          'FirstName': firstname,
          'Pwd': password,
        },
      );
      final token = body['token'] as String;
      final user = AuthUser.fromJson((body['user'] as Map).cast<String, dynamic>());
      await _store.save(token, user.toJson());
      state = AuthState(status: AuthStatus.authenticated, user: user);
      // The login response has no profile photo — /auth/me does.
      await refreshProfile();
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(error: 'Something went wrong. Please try again.');
      return false;
    } finally {
      _busy = false;
    }
  }

  /// Re-reads the logged-in user (e.g. after a new profile photo was set).
  Future<void> refreshProfile() async {
    try {
      final data = await ref.read(apiClientProvider).getData('/auth/me');
      final token = await _store.readToken();
      if (data is Map<String, dynamic> && token != null) {
        final user = AuthUser.fromJson(data);
        await _store.save(token, user.toJson());
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
    } catch (_) {
      // best effort — the drawer just keeps showing initials
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(apiClientProvider).postRaw('/auth/logout');
    } catch (_) {
      // ignore server-side failure, clear locally anyway
    }
    await _store.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called by the API client when any request comes back 401.
  Future<void> forceLogout() async {
    await _store.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
