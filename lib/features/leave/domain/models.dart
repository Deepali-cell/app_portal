import 'package:flutter/foundation.dart';

@immutable
class LeaveBalance {
  const LeaveBalance({
    required this.leaveType,
    required this.total,
    required this.taken,
    required this.pending,
    required this.remaining,
  });

  final String leaveType;
  final double total;
  final double taken;
  final double pending;
  final double remaining;

  factory LeaveBalance.fromJson(Map<String, dynamic> j) => LeaveBalance(
        leaveType: j['leave_type'] as String,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        taken: (j['taken'] as num?)?.toDouble() ?? 0,
        pending: (j['pending'] as num?)?.toDouble() ?? 0,
        remaining: (j['remaining'] as num?)?.toDouble() ?? 0,
      );
}

enum LeaveStatus { open, approved, rejected, cancelled }

LeaveStatus leaveStatusFrom(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'approved':
      return LeaveStatus.approved;
    case 'rejected':
      return LeaveStatus.rejected;
    case 'cancelled':
      return LeaveStatus.cancelled;
    default:
      return LeaveStatus.open;
  }
}

@immutable
class LeaveApplication {
  const LeaveApplication({
    required this.name,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.totalLeaveDays,
    required this.status,
    this.description,
    this.halfDay = false,
  });

  final String name;
  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final double totalLeaveDays;
  final LeaveStatus status;
  final String? description;
  final bool halfDay;

  factory LeaveApplication.fromJson(Map<String, dynamic> j) => LeaveApplication(
        name: j['name'] as String,
        leaveType: (j['leave_type'] ?? '') as String,
        fromDate: DateTime.parse(j['from_date'] as String),
        toDate: DateTime.parse(j['to_date'] as String),
        totalLeaveDays: (j['total_leave_days'] as num?)?.toDouble() ?? 0,
        status: leaveStatusFrom(j['status'] as String?),
        description: j['description'] as String?,
        halfDay: (j['half_day'] as num?)?.toInt() == 1,
      );
}

@immutable
class LeaveContext {
  const LeaveContext({
    required this.employee,
    required this.balances,
    required this.applications,
    required this.leaveTypes,
    required this.compensatoryLeaveTypes,
    this.leaveApprover,
  });

  final String employee;
  final String? leaveApprover;
  final List<LeaveBalance> balances;
  final List<LeaveApplication> applications;
  final List<String> leaveTypes;

  /// Subset of leave types where `is_compensatory=1`. Empty when comp-off
  /// isn't configured on the site; the mobile hides the Apply CTA in that case.
  final List<String> compensatoryLeaveTypes;

  bool get supportsCompOff => compensatoryLeaveTypes.isNotEmpty;

  factory LeaveContext.fromJson(Map<String, dynamic> j) => LeaveContext(
        employee: j['employee'] as String,
        leaveApprover: j['leave_approver'] as String?,
        balances: ((j['balances'] as List?) ?? [])
            .map((e) => LeaveBalance.fromJson(e as Map<String, dynamic>))
            .toList(),
        applications: ((j['applications'] as List?) ?? [])
            .map((e) => LeaveApplication.fromJson(e as Map<String, dynamic>))
            .toList(),
        leaveTypes: ((j['leave_types'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        compensatoryLeaveTypes:
            ((j['compensatory_leave_types'] as List?) ?? [])
                .map((e) => e.toString())
                .toList(),
      );
}

/// Form payload for an Apply-for-Comp-Off request.
@immutable
class CompOffRequest {
  const CompOffRequest({
    required this.workFromDate,
    required this.reason,
    this.workEndDate,
    this.leaveType,
  });
  final DateTime workFromDate;
  final DateTime? workEndDate;
  final String reason;
  final String? leaveType;
}

/// Form payload for a new leave request.
@immutable
class LeaveRequest {
  const LeaveRequest({
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.halfDay = false,
    this.halfDayDate,
    this.description,
  });

  final String leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final bool halfDay;
  final DateTime? halfDayDate;
  final String? description;
}
