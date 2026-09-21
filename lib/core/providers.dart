// lib/core/providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/auth_controller.dart';
import 'api_client.dart';
import 'auth_store.dart';

final authStoreProvider = Provider<AuthStore>((ref) => AuthStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  final store = ref.watch(authStoreProvider);
  return ApiClient(
    store,
    onUnauthorized: () async {
      // token rejected by the server -> drop local session
      await ref.read(authControllerProvider.notifier).forceLogout();
    },
  );
});
