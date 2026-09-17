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

  /// Expense claims waiting on the signed in user, as approver or as HR.
  Future<List<PendingExpenseApproval>> getPendingApprovals() async {
    try {
      final resp = await _dio.get(ApiPaths.expensePendingApprovals);
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return ((msg['claims'] as List?) ?? [])
          .map((e) =>
              PendingExpenseApproval.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Full detail of one claim (with line items), for the owner or an approver.
  Future<ExpenseClaimDetail> getClaimDetail(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.expenseClaimDetail,
        queryParameters: {'name': name},
      );
      return ExpenseClaimDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Approve or reject one claim. A rejection needs a reason, which the server
  /// also enforces.
  Future<void> actOnClaim({
    required String name,
    required String action,
    String? reason,
  }) async {
    try {
      await _dio.post(ApiPaths.expenseActOnClaim, data: {
        'name': name,
        'action': action,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
