/// Centralised runtime configuration.
///
/// Override at build/run time, e.g.:
///   flutter run --dart-define=TCB_BASE_URL=https://portal.example.com
///
/// Defaults target the local Frappe v16 bench. The v16 site `tcb.local` is the
/// served default site, so any Host works against the dev bench; in production
/// point [baseUrl] at the Cloudflare-tunnelled HTTPS domain.
class AppConfig {
  AppConfig._();

  /// Base URL of the Frappe server (scheme + host + optional port, no trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'TCB_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );

  /// Frappe site name. Only sent as a `Host` header when [sendHostHeader] is true
  /// (local multi-site dev over HTTP). Never override Host on an HTTPS domain.
  static const String siteHost = String.fromEnvironment(
    'TCB_SITE_HOST',
    defaultValue: 'tcb.local',
  );

  static const bool sendHostHeader = bool.fromEnvironment(
    'TCB_SEND_HOST_HEADER',
    defaultValue: false,
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Whether to require a biometric/device-credential unlock when restoring a
  /// session. Can be disabled per-deployment (or for tests) via dart-define.
  static const bool biometricLockEnabled = bool.fromEnvironment(
    'TCB_BIOMETRIC_LOCK',
    defaultValue: true,
  );

  static bool get isHttps => baseUrl.startsWith('https://');
}
