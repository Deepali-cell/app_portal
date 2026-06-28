import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/models.dart';

class DashboardRepository {
  DashboardRepository(this._dio);
  final Dio _dio;

  Future<SalesDashboard> fetch({String scope = 'mine'}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.salesDashboard,
        queryParameters: {'scope': scope},
      );
      return SalesDashboard.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
    (ref) => DashboardRepository(ref.watch(dioProvider)));

/// Mutable scope (My / Team) — managers can flip; non-managers locked to 'mine'.
class DashboardScopeController extends Notifier<String> {
  @override
  String build() => 'mine';
  void set(String s) => state = s;
}

final dashboardScopeProvider =
    NotifierProvider<DashboardScopeController, String>(
        DashboardScopeController.new);

final salesDashboardProvider =
    FutureProvider.autoDispose<SalesDashboard>((ref) {
  final scope = ref.watch(dashboardScopeProvider);
  return ref.read(dashboardRepositoryProvider).fetch(scope: scope);
});
