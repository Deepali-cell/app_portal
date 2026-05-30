import 'package:flutter/foundation.dart';

enum ClaimStatus { draft, submitted, approved, rejected, paid, unpaid, cancelled }

ClaimStatus claimStatusFrom(String? approval, String? status) {
  final a = (approval ?? '').toLowerCase();
  if (a == 'approved') return ClaimStatus.approved;
  if (a == 'rejected') return ClaimStatus.rejected;
  switch ((status ?? '').toLowerCase()) {
    case 'paid':
      return ClaimStatus.paid;
    case 'unpaid':
      return ClaimStatus.unpaid;
    case 'submitted':
      return ClaimStatus.submitted;
    case 'cancelled':
      return ClaimStatus.cancelled;
    default:
      return ClaimStatus.draft;
  }
}

@immutable
class ExpenseClaim {
  const ExpenseClaim({
    required this.name,
    required this.postingDate,
    required this.totalClaimed,
    required this.totalSanctioned,
    required this.status,
  });

  final String name;
  final DateTime postingDate;
  final double totalClaimed;
  final double totalSanctioned;
  final ClaimStatus status;

  factory ExpenseClaim.fromJson(Map<String, dynamic> j) => ExpenseClaim(
        name: j['name'] as String,
        postingDate: DateTime.parse(j['posting_date'] as String),
        totalClaimed: (j['total_claimed_amount'] as num?)?.toDouble() ?? 0,
        totalSanctioned: (j['total_sanctioned_amount'] as num?)?.toDouble() ?? 0,
        status: claimStatusFrom(
            j['approval_status'] as String?, j['status'] as String?),
      );
}

@immutable
class ExpenseContext {
  const ExpenseContext({
    required this.employee,
    required this.currency,
    required this.expenseTypes,
    required this.claims,
    required this.fromDate,
    required this.toDate,
  });

  final String employee;
  final String currency;
  final List<String> expenseTypes;
  final List<ExpenseClaim> claims;
  final DateTime fromDate;
  final DateTime toDate;

  factory ExpenseContext.fromJson(Map<String, dynamic> j) {
    final now = DateTime.now();
    return ExpenseContext(
      employee: j['employee'] as String,
      currency: (j['currency'] ?? 'INR') as String,
      expenseTypes: ((j['expense_types'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      claims: ((j['claims'] as List?) ?? [])
          .map((e) => ExpenseClaim.fromJson(e as Map<String, dynamic>))
          .toList(),
      fromDate: j['from_date'] != null
          ? DateTime.tryParse(j['from_date'].toString()) ??
              DateTime(now.year, now.month, 1)
          : DateTime(now.year, now.month, 1),
      toDate: j['to_date'] != null
          ? DateTime.tryParse(j['to_date'].toString()) ?? now
          : now,
    );
  }
}

/// One line in a new expense claim.
@immutable
class ExpenseItem {
  const ExpenseItem({
    required this.expenseType,
    required this.amount,
    this.description,
  });

  final String expenseType;
  final double amount;
  final String? description;

  Map<String, dynamic> toJson() => {
        'expense_type': expenseType,
        'amount': amount,
        if (description != null && description!.isNotEmpty)
          'description': description,
      };
}
