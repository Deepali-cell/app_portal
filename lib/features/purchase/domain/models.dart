import 'package:flutter/foundation.dart';

@immutable
class PurchaseOrderSummary {
  const PurchaseOrderSummary({
    required this.name,
    required this.supplierName,
    required this.status,
    required this.grandTotal,
    required this.currency,
    required this.transactionDate,
  });
  final String name;
  final String supplierName;
  final String status;
  final double grandTotal;
  final String currency;
  final String transactionDate;

  factory PurchaseOrderSummary.fromJson(Map<String, dynamic> j) =>
      PurchaseOrderSummary(
        name: (j['name'] ?? '').toString(),
        supplierName: (j['supplier_name'] ?? j['supplier'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0.0,
        currency: (j['currency'] ?? '').toString(),
        transactionDate: (j['transaction_date'] ?? '').toString(),
      );
}

@immutable
class PurchaseSummary {
  const PurchaseSummary({
    required this.draftMaterialRequests,
    required this.pendingRfqs,
    required this.pendingSupplierQuotations,
    required this.ordersToReceive,
    required this.ordersToBill,
    required this.receiptsToBill,
    required this.recentOrders,
  });
  final int draftMaterialRequests;
  final int pendingRfqs;
  final int pendingSupplierQuotations;
  final int ordersToReceive;
  final int ordersToBill;
  final int receiptsToBill;
  final List<PurchaseOrderSummary> recentOrders;

  factory PurchaseSummary.fromJson(Map<String, dynamic> j) => PurchaseSummary(
        draftMaterialRequests:
            (j['draft_material_requests'] as num?)?.toInt() ?? 0,
        pendingRfqs: (j['pending_rfqs'] as num?)?.toInt() ?? 0,
        pendingSupplierQuotations:
            (j['pending_supplier_quotations'] as num?)?.toInt() ?? 0,
        ordersToReceive: (j['orders_to_receive'] as num?)?.toInt() ?? 0,
        ordersToBill: (j['orders_to_bill'] as num?)?.toInt() ?? 0,
        receiptsToBill: (j['receipts_to_bill'] as num?)?.toInt() ?? 0,
        recentOrders: ((j['recent_orders'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => PurchaseOrderSummary.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}

@immutable
class QuotationComparisonRow {
  const QuotationComparisonRow({
    required this.name,
    required this.supplier,
    required this.supplierName,
    required this.status,
    required this.grandTotal,
    required this.currency,
    required this.rates,
  });
  final String name;
  final String supplier;
  final String supplierName;
  final String status;
  final double grandTotal;
  final String currency;
  final Map<String, double?> rates;

  factory QuotationComparisonRow.fromJson(Map<String, dynamic> j) =>
      QuotationComparisonRow(
        name: (j['name'] ?? '').toString(),
        supplier: (j['supplier'] ?? '').toString(),
        supplierName: (j['supplier_name'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
        grandTotal: (j['grand_total'] as num?)?.toDouble() ?? 0.0,
        currency: (j['currency'] ?? '').toString(),
        rates: ((j['rates'] as Map?) ?? const {}).map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toDouble()),
        ),
      );
}

@immutable
class QuotationComparison {
  const QuotationComparison({required this.items, required this.quotations});
  final List<String> items;
  final List<QuotationComparisonRow> quotations;

  factory QuotationComparison.fromJson(Map<String, dynamic> j) =>
      QuotationComparison(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        quotations: ((j['quotations'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                QuotationComparisonRow.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
}
