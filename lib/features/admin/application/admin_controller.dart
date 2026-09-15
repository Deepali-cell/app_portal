import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/admin_repository.dart';
import '../domain/models.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
    (ref) => AdminRepository(ref.watch(dioProvider)));

final adminMetaProvider = FutureProvider<AdminMeta>(
    (ref) => ref.read(adminRepositoryProvider).getMeta());

/// Holds the permission matrix for the currently-loaded role. `load(role)`
/// switches role; `toggle` optimistically updates and persists to Frappe.
class RoleMatrixController extends AsyncNotifier<Map<String, PermFlags>> {
  String? _role;
  String? get role => _role;

  @override
  Future<Map<String, PermFlags>> build() async => const {};

  Future<void> load(String role) async {
    _role = role;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(adminRepositoryProvider).getMatrix(role));
  }

  Future<void> toggle(String doctype, String ptype, bool value) async {
    final role = _role;
    final current = state.asData?.value;
    if (role == null || current == null) return;

    final optimistic = Map<String, PermFlags>.from(current);
    optimistic[doctype] =
        _apply(optimistic[doctype] ?? const PermFlags(), ptype, value);
    state = AsyncData(optimistic);

    try {
      final fresh = await ref.read(adminRepositoryProvider).setPerm(
            role: role,
            doctype: doctype,
            ptype: ptype,
            value: value,
          );
      final updated =
          Map<String, PermFlags>.from(state.asData?.value ?? optimistic);
      updated[doctype] = fresh;
      state = AsyncData(updated);
    } catch (_) {
      state = AsyncData(current); // revert
      rethrow;
    }
  }

  PermFlags _apply(PermFlags f, String ptype, bool v) => PermFlags(
        read: ptype == 'read' ? v : f.read,
        create: ptype == 'create' ? v : f.create,
        write: ptype == 'write' ? v : f.write,
        submit: ptype == 'submit' ? v : f.submit,
        delete: ptype == 'delete' ? v : f.delete,
        ifOwner: ptype == 'if_owner' ? v : f.ifOwner,
      );
}

final roleMatrixProvider =
    AsyncNotifierProvider<RoleMatrixController, Map<String, PermFlags>>(
        RoleMatrixController.new);
