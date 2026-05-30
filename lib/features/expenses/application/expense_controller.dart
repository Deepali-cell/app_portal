import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/expense_repository.dart';
import '../domain/models.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
    (ref) => ExpenseRepository(ref.watch(dioProvider)));

final expenseControllerProvider =
    AsyncNotifierProvider<ExpenseController, ExpenseContext>(
        ExpenseController.new);

class ExpenseController extends AsyncNotifier<ExpenseContext> {
  DateTime? _from;
  DateTime? _to;

  DateTime get from {
    final f = _from;
    if (f != null) return f;
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get to => _to ?? DateTime.now();

  @override
  Future<ExpenseContext> build() =>
      ref.read(expenseRepositoryProvider).getContext(from: from, to: to);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(expenseRepositoryProvider).getContext(from: from, to: to),
    );
  }

  Future<void> setRange(DateTime newFrom, DateTime newTo) async {
    _from = newFrom;
    _to = newTo;
    await reload();
  }

  Future<void> apply(List<ExpenseItem> items, {String? remark}) async {
    await ref.read(expenseRepositoryProvider).apply(items, remark: remark);
    await reload();
  }
}
