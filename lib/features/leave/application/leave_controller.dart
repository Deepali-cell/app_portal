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

  /// Approve or reject one request. Refreshes both the approvals list and the
  /// leave context, since the pending count on the leave screen changes too.
  Future<void> actOnApplication({
    required String name,
    required String action,
    String? reason,
  }) async {
    await ref.read(leaveRepositoryProvider).actOnApplication(
          name: name,
          action: action,
          reason: reason,
        );
    ref.invalidate(pendingLeaveApprovalsProvider);
    await reload();
  }

  /// Approve or reject one comp-off request, then refresh the comp-off
  /// approvals list and the leave context (its pending count changes too).
  Future<void> actOnCompOff({
    required String name,
    required String action,
    String? reason,
  }) async {
    await ref.read(leaveRepositoryProvider).actOnCompOff(
          name: name,
          action: action,
          reason: reason,
        );
    ref.invalidate(pendingCompOffApprovalsProvider);
    await reload();
  }
}

/// On-demand detail for a single Leave Application.
final leaveApplicationDetailProvider =
    FutureProvider.family<LeaveApplicationDetail, String>(
        (ref, name) => ref
            .read(leaveRepositoryProvider)
            .getApplicationDetail(name));

/// Requests waiting on the signed in user, as manager or as HR.
final pendingLeaveApprovalsProvider =
    FutureProvider<List<PendingLeaveApproval>>(
        (ref) => ref.read(leaveRepositoryProvider).getPendingApprovals());

/// Comp-off requests waiting on the signed in user, as manager or as HR.
final pendingCompOffApprovalsProvider =
    FutureProvider<List<PendingCompOffApproval>>(
        (ref) => ref.read(leaveRepositoryProvider).getCompOffPendingApprovals());
