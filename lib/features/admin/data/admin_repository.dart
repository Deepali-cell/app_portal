import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class AdminRepository {
  AdminRepository(this._dio);
  final Dio _dio;

  Future<AdminMeta> getMeta() async {
    try {
      final resp = await _dio.get(ApiPaths.adminMeta);
      return AdminMeta.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Returns {doctype: PermFlags} for the given role at permlevel 0.
  Future<Map<String, PermFlags>> getMatrix(String role) async {
    try {
      final resp = await _dio.get(
        ApiPaths.adminRoleMatrix,
        queryParameters: {'role': role},
      );
      final map = (resp.data['message'] as Map).cast<String, dynamic>();
      return map.map((dt, v) =>
          MapEntry(dt, PermFlags.fromJson((v as Map).cast<String, dynamic>())));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<PermFlags> setPerm({
    required String role,
    required String doctype,
    required String ptype,
    required bool value,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.adminSetPerm,
        data: {
          'role': role,
          'doctype': doctype,
          'ptype': ptype,
          'value': value ? 1 : 0,
        },
      );
      return PermFlags.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  // --- Reports: per-role access to the curated reports ---------------------

  Future<ReportAdminMeta> getReportMeta() async {
    try {
      final resp = await _dio.get(ApiPaths.adminReportMeta);
      return ReportAdminMeta.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportRolesState> getReportRoles(String reportKey) async {
    try {
      final resp = await _dio.get(
        ApiPaths.adminReportRoles,
        queryParameters: {'report_key': reportKey},
      );
      return ReportRolesState.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ReportRolesState> setReportRole({
    required String reportKey,
    required String role,
    required bool value,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.adminSetReportRole,
        data: {
          'report_key': reportKey,
          'role': role,
          'value': value ? 1 : 0,
        },
      );
      return ReportRolesState.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
