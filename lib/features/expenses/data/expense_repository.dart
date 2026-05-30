import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class ExpenseRepository {
  ExpenseRepository(this._dio);
  final Dio _dio;

  Future<ExpenseContext> getContext({DateTime? from, DateTime? to}) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    try {
      final resp = await _dio.get(
        ApiPaths.expenseContext,
        queryParameters: {
          if (from != null) 'from_date': fmt(from),
          if (to != null) 'to_date': fmt(to),
        },
      );
      return ExpenseContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Creates a draft expense claim. Throws [ApiException] on rejection.
  Future<void> apply(List<ExpenseItem> items, {String? remark}) async {
    try {
      await _dio.post(ApiPaths.expenseApply, data: {
        'items': jsonEncode(items.map((e) => e.toJson()).toList()),
        if (remark != null && remark.isNotEmpty) 'remark': remark,
      });
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
