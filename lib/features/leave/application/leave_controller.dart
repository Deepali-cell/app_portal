import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/leave_repository.dart';
import '../domain/models.dart';

final leaveRepositoryProvider =
    Provider<LeaveRepository>((ref) => LeaveRepository(ref.watch(dioProvider)));

final leaveControllerProvider =
    AsyncNotifierProvider<LeaveController, LeaveContext>(LeaveController.new);

class LeaveController extends AsyncNotifier<LeaveContext> {
  @override
  Future<LeaveContext> build() =>
      ref.read(leaveRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(leaveRepositoryProvider).getContext(),
    );
  }

  /// Submits a new request then refreshes. Throws [ApiException] on rejection.
  Future<void> apply(LeaveRequest request) async {
    await ref.read(leaveRepositoryProvider).apply(request);
    await reload();
  }

  /// Submits a Compensatory Leave Request (comp-off claim) then refreshes.
  /// Throws [ApiException] on rejection.
  Future<void> applyCompOff(CompOffRequest request) async {
    await ref.read(leaveRepositoryProvider).applyCompOff(request);
    await reload();
  }
}

/// On-demand detail for a single Leave Application.
final leaveApplicationDetailProvider =
    FutureProvider.family<LeaveApplicationDetail, String>(
        (ref, name) => ref
            .read(leaveRepositoryProvider)
            .getApplicationDetail(name));
