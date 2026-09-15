import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../domain/models.dart';

class StockRepository {
  StockRepository(this._dio);
  final Dio _dio;

  Future<List<Item>> listItems({String? search, int limit = 50}) async {
    try {
      final resp = await _dio.get(
        ApiPaths.stockListItems,
        queryParameters: {
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': limit,
        },
      );
      final list = (resp.data['message'] as List?) ?? const [];
      return list
          .map((e) => Item.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<ItemDetail> getItem(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.stockGetItem,
        queryParameters: {'name': name},
      );
      return ItemDetail.fromJson(
        (resp.data['message'] as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
