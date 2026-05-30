import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class LeaveRepository {
  LeaveRepository(this._dio);
  final Dio _dio;

  Future<LeaveContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.leaveContext);
      return LeaveContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  /// Submits a leave request. Throws [ApiException] (e.g. insufficient balance,
  /// overlapping leave) for the UI to surface.
  Future<void> apply(LeaveRequest req) async {
    try {
      await _dio.post(ApiPaths.leaveApply, data: {
        'leave_type': req.leaveType,
        'from_date': _ymd(req.fromDate),
        'to_date': _ymd(req.toDate),
        'half_day': req.halfDay ? 1 : 0,
        if (req.halfDay && req.halfDayDate != null)
          'half_day_date': _ymd(req.halfDayDate!),
        if (req.description != null && req.description!.isNotEmpty)
          'description': req.description,
      });
    } on DioException catch (e) {
      throw _asApiException(e);
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  ApiException _asApiException(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
