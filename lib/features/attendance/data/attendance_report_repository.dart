import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/attendance_report_models.dart';

/// Attendance calendar / history / HR-management data, backed by
/// tcb_portal_erp.api.attendance_report. The everyday clock-in/out flow stays
/// in AttendanceRepository - this only covers the read-back views + HR marking.
class AttendanceReportRepository {
  AttendanceReportRepository(this._dio);
  final Dio _dio;

  Future<AttendanceMonth> monthly(int year, int month, {String? employee}) async {
    final data = await _get(ApiPaths.attendanceMonthly, {
      'year': year,
      'month': month,
      if (employee != null) 'employee': employee,
    });
    return AttendanceMonth.fromJson(data);
  }

  Future<DayLogs> dayLogs(DateTime date, {String? employee}) async {
    final data = await _get(ApiPaths.attendanceDayLogs, {
      'date': _ymd(date),
      if (employee != null) 'employee': employee,
    });
    return DayLogs.fromJson(data);
  }

  Future<AttendanceRoster> roster(int year, int month, {String? search}) async {
    final data = await _get(ApiPaths.attendanceRoster, {
      'year': year,
      'month': month,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    return AttendanceRoster.fromJson(data);
  }

  Future<String> markStatus({
    required String employee,
    required DateTime date,
    required String status,
    String? halfDayStatus,
  }) async {
    final data = await _post(ApiPaths.attendanceMarkStatus, {
      'employee': employee,
      'date': _ymd(date),
      'status': status,
      if (halfDayStatus != null) 'half_day_status': halfDayStatus,
    });
    return (data['name'] ?? '').toString();
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> _get(String path, Map<String, dynamic> query) async {
    try {
      final resp = await _dio.get(path, queryParameters: query);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post(path, data: data);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final attendanceReportRepositoryProvider = Provider<AttendanceReportRepository>(
  (ref) => AttendanceReportRepository(ref.watch(dioProvider)),
);

/// Family key for a month view: (year, month, employee) - null employee = self.
typedef MonthKey = ({int year, int month, String? employee});

final monthlyAttendanceProvider =
    FutureProvider.autoDispose.family<AttendanceMonth, MonthKey>((ref, key) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .monthly(key.year, key.month, employee: key.employee);
});

typedef RosterKey = ({int year, int month, String? search});

final attendanceRosterProvider =
    FutureProvider.autoDispose.family<AttendanceRoster, RosterKey>((ref, key) {
  return ref
      .read(attendanceReportRepositoryProvider)
      .roster(key.year, key.month, search: key.search);
});
