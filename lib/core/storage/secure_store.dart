import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Riverpod provider for the singleton [SecureStore].
final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

/// Encrypted key/value store for the API token and the cached user profile.
///
/// Backed by the platform keystore/keychain via `flutter_secure_storage`
/// (Keychain on iOS, encrypted storage on Android). Plaintext credentials are
/// never persisted; only the derived `api_key:api_secret` token is kept.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kToken = 'tcb.auth.token';
  static const _kProfile = 'tcb.auth.profile';
  static const _kTenant = 'tcb.tenant';

  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<bool> hasToken() async => (await readToken())?.isNotEmpty ?? false;

  Future<void> writeProfile(String json) =>
      _storage.write(key: _kProfile, value: json);

  Future<String?> readProfile() => _storage.read(key: _kProfile);

  /// The serialised current [Tenant] (resolved via the middleware on login).
  Future<void> writeTenant(String json) =>
      _storage.write(key: _kTenant, value: json);

  Future<String?> readTenant() => _storage.read(key: _kTenant);

  Future<void> clearTenant() => _storage.delete(key: _kTenant);

  /// Sign-out: clears the auth token and cached profile. The tenant is
  /// intentionally preserved so the login screen stays pre-themed for the
  /// returning user. Use [clearAll] for "Switch company".
  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kProfile);
  }

  /// Full wipe — used by "Switch company" to reset everything.
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
