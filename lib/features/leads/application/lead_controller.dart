import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/lead_repository.dart';
import '../domain/models.dart';

final leadRepositoryProvider =
    Provider<LeadRepository>((ref) => LeadRepository(ref.watch(dioProvider)));

final leadsControllerProvider =
    AsyncNotifierProvider<LeadsController, LeadsContext>(LeadsController.new);

class LeadsController extends AsyncNotifier<LeadsContext> {
  @override
  Future<LeadsContext> build() =>
      ref.read(leadRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(leadRepositoryProvider).getContext());
  }

  Future<void> create(Map<String, dynamic> fields) async {
    await ref.read(leadRepositoryProvider).create(fields);
    await reload();
  }

  Future<void> save(String name, Map<String, dynamic> fields) async {
    await ref.read(leadRepositoryProvider).update(name, fields);
    ref.invalidate(leadDetailProvider(name));
    await reload();
  }

  /// Convert this Lead to an ERPNext Customer (post-2026-06-29 migration).
  /// Returns the new Customer's name on success.
  Future<String> convertToCustomer(String name) async {
    final customer =
        await ref.read(leadRepositoryProvider).convertToCustomer(name);
    ref.invalidate(leadDetailProvider(name));
    await reload();
    return customer;
  }

  /// Backwards-compat alias — kept so older callers keep compiling.
  Future<String> convertToDeal(String name) => convertToCustomer(name);
}

/// Detail for a single lead, fetched on demand by name.
final leadDetailProvider = FutureProvider.family<Lead, String>(
  (ref, name) => ref.read(leadRepositoryProvider).getDetail(name),
);
