import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/providers.dart';

/// Manufacturing-cycle conversion actions, backed by
/// tcb_portal_erp.api.manufacturing. Everyday CRUD for BOM / Work Order /
/// Job Card / Stock Entry goes through the generic RecordsRepository - this
/// repository only covers the step-to-step conversions that engine doesn't do.
class ManufacturingRepository {
  ManufacturingRepository(this._dio);
  final Dio _dio;

  Future<String> createWorkOrderFromBom(String bom, {double qty = 1}) async {
    final data = await _post(
        ApiPaths.mfgCreateWorkOrderFromBom, {'bom': bom, 'qty': qty});
    return (data['name'] ?? '').toString();
  }

  /// `purpose` is "Material Transfer for Manufacture" or "Manufacture".
  Future<String> createStockEntryFromWorkOrder(
    String workOrder, {
    required String purpose,
  }) async {
    final data = await _post(ApiPaths.mfgCreateStockEntryFromWorkOrder,
        {'work_order': workOrder, 'purpose': purpose});
    return (data['name'] ?? '').toString();
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> data) async {
    try {
      final resp = await _dio.post(path, data: data);
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final manufacturingRepositoryProvider = Provider<ManufacturingRepository>(
    (ref) => ManufacturingRepository(ref.watch(dioProvider)));
