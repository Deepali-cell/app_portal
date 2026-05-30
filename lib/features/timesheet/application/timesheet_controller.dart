import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/timesheet_repository.dart';
import '../domain/models.dart';

final timesheetRepositoryProvider = Provider<TimesheetRepository>(
    (ref) => TimesheetRepository(ref.watch(dioProvider)));

final timesheetControllerProvider =
    AsyncNotifierProvider<TimesheetController, TimesheetContext>(
        TimesheetController.new);

class TimesheetController extends AsyncNotifier<TimesheetContext> {
  DateTime? _from;
  DateTime? _to;

  DateTime get from {
    final f = _from;
    if (f != null) return f;
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  DateTime get to {
    final t = _to;
    if (t != null) return t;
    return DateTime.now();
  }

  @override
  Future<TimesheetContext> build() =>
      ref.read(timesheetRepositoryProvider).getContext(from: from, to: to);

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref
        .read(timesheetRepositoryProvider)
        .getContext(from: from, to: to));
  }

  Future<void> setRange(DateTime newFrom, DateTime newTo) async {
    _from = newFrom;
    _to = newTo;
    await reload();
  }

  Future<void> create(List<TimeLog> logs, {String? note}) async {
    await ref.read(timesheetRepositoryProvider).create(logs, note: note);
    await reload();
  }

  Future<ActiveTimer> startTimer({
    required String activityType,
    required String project,
    required String task,
  }) async {
    final timer = await ref.read(timesheetRepositoryProvider).startTimer(
          activityType: activityType,
          project: project,
          task: task,
        );
    ref.invalidate(activeTimerProvider);
    await reload();
    return timer;
  }

  Future<void> stopTimer(String description) async {
    await ref.read(timesheetRepositoryProvider).stopTimer(description);
    ref.invalidate(activeTimerProvider);
    await reload();
  }

  Future<void> submitTimesheet(String name) async {
    await ref.read(timesheetRepositoryProvider).submitTimesheet(name);
    await reload();
  }
}

/// Active timer for the current user. Refreshed by start/stop actions and on
/// timesheet screen entry. Returns null when nothing is running.
final activeTimerProvider = FutureProvider<ActiveTimer?>(
    (ref) => ref.read(timesheetRepositoryProvider).getActiveTimer());

/// Tasks for a project — fetched on-demand in the start sheet.
final projectTasksProvider =
    FutureProvider.family<List<TaskRef>, String>((ref, project) {
  if (project.isEmpty) return Future.value(const []);
  return ref.read(timesheetRepositoryProvider).getProjectTasks(project);
});

/// On-demand detail for a single Timesheet.
final timesheetDetailProvider =
    FutureProvider.family<TimesheetDetail, String>((ref, name) {
  return ref.read(timesheetRepositoryProvider).getDetail(name);
});
