import 'package:flutter/foundation.dart';

@immutable
class SalesOrderSummary {
  const SalesOrderSummary({
    required this.name,
    required this.customerName,
    required this.status,
    required this.grandTotal,
    required this.currency,
    required this.transactionDate,
  });
  final String name;
  final String customerName;
  final String status;
  final double grandTotal;
  final String currency;
  final String transactionDate;

  factory SalesOrderSummary.fromJson(Map<String, dynamic> j) =>
      SalesOrderSummary(
        name: (j['name'] ?? '').toString(),
        customerName: (j['customer_name'] ?? j['customer'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0.0,
        currency: (j['currency'] ?? '').toString(),
        transactionDate: (j['transaction_date'] ?? '').toString(),
      );
}

@immutable
class SalesSummary {
  const SalesSummary({
    required this.openQuotations,
    required this.ordersToDeliver,
    required this.ordersToBill,
    required this.notesToBill,
    required this.unpaidInvoices,
    required this.recentOrders,
  });
  final int openQuotations;
  final int ordersToDeliver;
  final int ordersToBill;
  final int notesToBill;
  final int unpaidInvoices;
  final List<SalesOrderSummary> recentOrders;

  factory SalesSummary.fromJson(Map<String, dynamic> j) => SalesSummary(
        openQuotations: (j['open_quotations'] as num?)?.toInt() ?? 0,
        ordersToDeliver: (j['orders_to_deliver'] as num?)?.toInt() ?? 0,
        ordersToBill: (j['orders_to_bill'] as num?)?.toInt() ?? 0,
        notesToBill: (j['notes_to_bill'] as num?)?.toInt() ?? 0,
        unpaidInvoices: (j['unpaid_invoices'] as num?)?.toInt() ?? 0,
        recentOrders: ((j['recent_orders'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => SalesOrderSummary.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
