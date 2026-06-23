import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/tenant.dart';

/// Calls the TCB middleware's tenant resolve endpoint.
///
/// Uses its own short-lived Dio instance pointed at [AppConfig.middlewareBaseUrl]
/// — NOT the per-tenant ERPNext URL (which we don't have yet). This is the
/// only call the mobile ever makes against the middleware, and it happens
/// once per Company-ID entry (i.e. once per login, or once when "Switch
/// company" is used).
class TenantRepository {
  TenantRepository();

  Future<Tenant> resolve(String companyId) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.middlewareBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        responseType: ResponseType.json,
        headers: {
          'Accept': 'application/json',
          if (AppConfig.sendHostHeader) 'Host': AppConfig.siteHost,
        },
        validateStatus: (code) => code != null && code < 400,
      ),
    );
    try {
      final resp = await dio.get(
        ApiPaths.tenantResolve,
        queryParameters: {'company_id': companyId.trim()},
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      // Normalise the logo URL: backend may return a site-relative path
      // (e.g. /files/acme.png) or an absolute URL whose host is internal
      // (tcb.local). Either way, the mobile needs a URL it can fetch
      // directly. Re-anchor any relative-looking path to the middleware base.
      msg['logo_url'] = _absoluteLogoUrl(msg['logo_url'] as String?);
      return Tenant.fromResolveResponse(msg);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      dio.close(force: true);
    }
  }

  /// Logo paths from Frappe can be `/files/x.png`, `/private/files/x.png`,
  /// or absolute URLs against an internal host like `http://tcb.local/...`.
  /// Rewrite to an absolute URL the phone can reach via the middleware.
  static String? _absoluteLogoUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim();
    final base = AppConfig.middlewareBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (s.startsWith('/')) return '$base$s';
    if (s.startsWith('http://') || s.startsWith('https://')) {
      // If it already points at the middleware host, keep as-is.
      if (s.startsWith(base)) return s;
      // Strip the embedded host and re-anchor to the middleware.
      final idx = s.indexOf('/', s.indexOf('://') + 3);
      if (idx > 0) return '$base${s.substring(idx)}';
      return s;
    }
    // Bare filename — assume /files/.
    return '$base/files/$s';
  }
}
