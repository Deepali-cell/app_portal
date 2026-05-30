import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class PayslipRepository {
  PayslipRepository(this._dio);
  final Dio _dio;

  Future<PayslipContext> getList({DateTime? from, DateTime? to}) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.payslipList,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
        },
      );
      return PayslipContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  Future<PayslipDetail> getDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.payslipDetail,
        queryParameters: {'name': name},
      );
      return PayslipDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
