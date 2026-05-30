import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/task_repository.dart';
import '../domain/models.dart';

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) => TaskRepository(ref.watch(dioProvider)));

final taskControllerProvider =
    AsyncNotifierProvider<TaskController, TaskContext>(TaskController.new);

class TaskController extends AsyncNotifier<TaskContext> {
  @override
  Future<TaskContext> build() => ref.read(taskRepositoryProvider).getContext();

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => ref.read(taskRepositoryProvider).getContext());
  }

  Future<void> create({
    required String subject,
    String? description,
    String? priority,
    DateTime? expEndDate,
    String? project,
  }) async {
    await ref.read(taskRepositoryProvider).create(
          subject: subject,
          description: description,
          priority: priority,
          expEndDate: expEndDate,
          project: project,
        );
    await reload();
  }

  Future<void> setStatus(String name, String status) async {
    await ref.read(taskRepositoryProvider).setStatus(name, status);
    await reload();
  }
}
