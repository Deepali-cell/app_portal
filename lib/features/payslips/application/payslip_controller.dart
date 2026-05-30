import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/payslip_repository.dart';
import '../domain/models.dart';

final payslipRepositoryProvider = Provider<PayslipRepository>(
    (ref) => PayslipRepository(ref.watch(dioProvider)));

final payslipListProvider =
    AsyncNotifierProvider<PayslipListController, PayslipContext>(
        PayslipListController.new);

class PayslipListController extends AsyncNotifier<PayslipContext> {
  DateTime? _from;
  DateTime? _to;

  DateTime get from {
    final f = _from;
    if (f != null) return f;
    return DateTime(DateTime.now().year, 1, 1);
  }

  DateTime get to => _to ?? DateTime.now();

  @override
  Future<PayslipContext> build() =>
      ref.read(payslipRepositoryProvider).getList(from: from, to: to);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(payslipRepositoryProvider).getList(from: from, to: to),
    );
  }

  Future<void> setRange(DateTime newFrom, DateTime newTo) async {
    _from = newFrom;
    _to = newTo;
    await reload();
  }
}

/// Detail for a single payslip, fetched on demand by name.
final payslipDetailProvider =
    FutureProvider.family<PayslipDetail, String>((ref, name) {
  return ref.read(payslipRepositoryProvider).getDetail(name);
});
