import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_repository.dart';
import 'network/dio_client.dart';
import 'storage/secure_store.dart';

/// Encrypted credential store.
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Owns the configured Dio instance. On an auth rejection it forces sign-out.
///
/// The [onUnauthorized] closure reads the auth controller lazily (only when a
/// 401/403 actually occurs), so there is no build-time dependency cycle with
/// [authControllerProvider].
final dioClientProvider = Provider<DioClient>((ref) {
  final store = ref.watch(secureStoreProvider);
  return DioClient(
    store,
    onUnauthorized: () =>
        ref.read(authControllerProvider.notifier).forceLogout(),
  );
});

final dioProvider = Provider<Dio>((ref) => ref.watch(dioClientProvider).dio);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider), ref.watch(secureStoreProvider)),
);
