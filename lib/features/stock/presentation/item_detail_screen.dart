import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../auth/application/auth_controller.dart';
import '../application/stock_controller.dart';

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(itemDetailProvider(name));
    final profile = ref.watch(authControllerProvider.select((s) => s.profile));
    final canEdit = profile?.canDo('stock_item', 'write') ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Item'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit Item - coming soon')),
              ),
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (item) => ListView(
          padding: const EdgeInsets.all(AppDimens.md),
          children: [
            Text(item.itemName.isEmpty ? item.itemCode : item.itemName,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppDimens.xs),
            Text(item.itemCode,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppDimens.lg),
            _row('Item Group', item.itemGroup),
            _row('Stock UOM', item.stockUom),
            _row('Stock Item', item.isStockItem ? 'Yes' : 'No'),
            _row('Sales Item', item.isSalesItem ? 'Yes' : 'No'),
            _row('Purchase Item', item.isPurchaseItem ? 'Yes' : 'No'),
            _row('Valuation Rate', item.valuationRate?.toString()),
            _row('Standard Rate', item.standardRate?.toString()),
            if ((item.description ?? '').isNotEmpty) ...[
              const SizedBox(height: AppDimens.md),
              Text('Description',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppDimens.xs),
              Text(item.description!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
