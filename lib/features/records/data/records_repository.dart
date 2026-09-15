import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:convert';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';
import '../domain/form_meta.dart';

class RecordsRepository {
  RecordsRepository(this._dio);
  final Dio _dio;

  Future<List<Map<String, dynamic>>> listDocs(
    String doctype, {
    String? search,
    int limit = 50,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalListDocs,
        queryParameters: {
          'doctype': doctype,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
        },
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Map<String, dynamic>> getDoc(String doctype, String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalGetDoc,
        queryParameters: {'doctype': doctype, 'name': name},
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<FormMeta> getFormMeta(String doctype) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalFormMeta,
        queryParameters: {'doctype': doctype},
      );
      return FormMeta.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<List<Map<String, String>>> searchLink(String doctype,
      {String txt = ''}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.portalSearchLink,
        queryParameters: {'doctype': doctype, 'txt': txt, 'limit': 20},
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => {
                'value': (e['value'] ?? '').toString(),
                'label': (e['label'] ?? e['value'] ?? '').toString(),
              })
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Insert (name null) or update, optionally submit. Returns {name, docstatus}.
  Future<Map<String, dynamic>> saveDoc(
    String doctype,
    Map<String, dynamic> values, {
    String? name,
    bool submit = false,
  }) async {
    try {
      final resp = await _dio.post(
        ApiPaths.portalSaveDoc,
        data: {
          'doctype': doctype,
          'values': jsonEncode(values),
          if (name != null) 'name': name,
          'submit': submit ? 1 : 0,
        },
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final recordsRepositoryProvider = Provider<RecordsRepository>(
    (ref) => RecordsRepository(ref.watch(dioProvider)));
