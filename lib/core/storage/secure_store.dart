import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

  Future<void> writeToken(String token) =>
      _storage.write(key: _kToken, value: token);

  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<bool> hasToken() async => (await readToken())?.isNotEmpty ?? false;

  Future<void> writeProfile(String json) =>
      _storage.write(key: _kProfile, value: json);

  Future<String?> readProfile() => _storage.read(key: _kProfile);

  /// Clears all sensitive data (sign-out).
  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kProfile);
  }
}
