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
      return Tenant.fromResolveResponse(msg);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } finally {
      dio.close(force: true);
    }
  }
}
