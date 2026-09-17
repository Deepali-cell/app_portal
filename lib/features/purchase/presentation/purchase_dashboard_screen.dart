import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/money.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../records/domain/descriptor.dart';
import '../data/purchase_repository.dart';
import '../domain/models.dart';

/// Purchase module landing screen: pipeline counters + recent Purchase
/// Orders. Mirrors the role_dashboards KPI-tile style used elsewhere in the
/// app (HR/Projects/Accounts) for visual consistency.
class PurchaseDashboardScreen extends ConsumerWidget {
  const PurchaseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(purchaseDashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Purchase')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(purchaseDashboardProvider),
        child: async.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Center(child: Text('$e', textAlign: TextAlign.center)),
              const SizedBox(height: AppDimens.md),
              Center(
                child: FilledButton(
                  onPressed: () => ref.invalidate(purchaseDashboardProvider),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (s) => _Body(summary: s),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final PurchaseSummary summary;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDimens.md),
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.playlist_add_outlined,
                label: 'Draft Material Requests',
                value: '${summary.draftMaterialRequests}',
                route: Routes.stockMaterialRequest,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.request_quote_outlined,
                label: 'Pending RFQs',
                value: '${summary.pendingRfqs}',
                route: Routes.purchaseRfq,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.description_outlined,
                label: 'Pending Supplier Quotations',
                value: '${summary.pendingSupplierQuotations}',
                route: Routes.purchaseSupplierQuotation,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.local_shipping_outlined,
                label: 'Orders to Receive',
                value: '${summary.ordersToReceive}',
                tone: summary.ordersToReceive > 0 ? _Tone.warn : _Tone.primary,
                route: Routes.purchaseOrder,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.sm),
        Row(
          children: [
            Expanded(
              child: _KpiTile(
                icon: Icons.receipt_long_outlined,
                label: 'Orders to Bill',
                value: '${summary.ordersToBill}',
                tone: summary.ordersToBill > 0 ? _Tone.warn : _Tone.primary,
                route: Routes.purchaseOrder,
              ),
            ),
            const SizedBox(width: AppDimens.sm),
            Expanded(
              child: _KpiTile(
                icon: Icons.inventory_2_outlined,
                label: 'Receipts to Bill',
                value: '${summary.receiptsToBill}',
                tone: summary.receiptsToBill > 0 ? _Tone.warn : _Tone.primary,
                route: Routes.purchaseReceipt,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.lg),
        Text('Recent Purchase Orders',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: AppDimens.sm),
        if (summary.recentOrders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimens.md),
            child: Text('No purchase orders yet',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          )
        else
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final o in summary.recentOrders) _orderRow(context, o),
              ],
            ),
          ),
      ],
    );
  }

  Widget _orderRow(BuildContext context, PurchaseOrderSummary o) {
    return ListTile(
      title: Text(o.supplierName.isNotEmpty ? o.supplierName : o.name),
      subtitle: Text('${o.name}  •  ${o.status}'),
      trailing: Text(
        moneyShort(o.grandTotal, currencyCode: o.currency),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: () => context.push(
        Routes.recordDetail,
        extra: RecordArgs(recordRegistry['purchase_order']!, o.name),
      ),
    );
  }
}

enum _Tone { primary, warn }

class _KpiTile extends StatelessWidget {
  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.route,
    this.tone = _Tone.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final String route;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = tone == _Tone.warn
        ? (const Color(0xFFFFF3E0), const Color(0xFFE65100))
        : (AppColors.surfaceContainerLowest, AppColors.primary);

    return InkWell(
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      onTap: () => context.go(route),
      child: Container(
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(AppDimens.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
