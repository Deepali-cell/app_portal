import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class TaskRepository {
  TaskRepository(this._dio);
  final Dio _dio;

  Future<TaskContext> getContext() async {
    try {
      final resp = await _dio.get(ApiPaths.taskContext);
      return TaskContext.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> create({
    required String subject,
    String? description,
    String? priority,
    DateTime? expEndDate,
    String? project,
  }) async {
    final data = <String, dynamic>{'subject': subject};
    if (description != null && description.isNotEmpty) {
      data['description'] = description;
    }
    if (priority != null) data['priority'] = priority;
    if (expEndDate != null) {
      data['exp_end_date'] = expEndDate.toIso8601String().split('.').first;
    }
    if (project != null) data['project'] = project;
    try {
      await _dio.post(ApiPaths.taskCreate, data: data);
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  Future<void> setStatus(String name, String status) async {
    try {
      await _dio.post(ApiPaths.taskSetStatus,
          data: {'name': name, 'status': status});
    } on DioException catch (e) {
      throw _err(e);
    }
  }

  ApiException _err(DioException e) =>
      e.error is ApiException ? e.error as ApiException : ApiException.fromDio(e);
}
