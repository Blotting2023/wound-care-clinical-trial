import 'package:dio/dio.dart';

import '../models/api_response.dart';
import '../models/center.dart';
import '../models/protocol.dart';
import '../models/protocol_center_allocation.dart';
import '../models/protocol_document.dart';
import 'api_client.dart';

/// Trial-protocol CRUD — manages the umbrella record per investigation.
class ProtocolService {
  final ApiClient _apiClient;
  ProtocolService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<ApiResponse<List<Protocol>>> listProtocols({
    String? status,
  }) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/protocols',
        queryParameters: {if (status != null) 'status': status},
      );
      final raw = (res.data?['data'] as List<dynamic>?) ??
          (res.data?['content'] as List<dynamic>?) ??
          [];
      final list = raw
          .map((e) => Protocol.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<Protocol>>(
        success: true,
        message: 'OK',
        data: list,
        totalCount: list.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取方案列表失败',
      );
    }
  }

  Future<ApiResponse<Protocol>> getProtocol(String id) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/protocols/$id');
      if (res.data == null) return ApiResponse.error(message: '方案不存在');
      return ApiResponse.ok(data: Protocol.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取方案失败',
      );
    }
  }

  Future<ApiResponse<Protocol>> createProtocol({
    required String code,
    required String name,
    required String version,
    required String sponsor,
    required String phase,
    required DateTime startDate,
    String? summary,
  }) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/protocols',
        data: {
          'code': code,
          'name': name,
          'version': version,
          'sponsor': sponsor,
          'phase': phase,
          'startDate': startDate.toIso8601String(),
          'summary': summary,
        },
      );
      if (res.data == null) return ApiResponse.error(message: '创建方案失败');
      return ApiResponse.ok(
          message: '方案已创建', data: Protocol.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '创建方案失败',
      );
    }
  }
  /// W6 — 方案文档：列表 + 上传（元数据；字节 V4 走 COS）。
  Future<ApiResponse<List<ProtocolDocument>>> listDocuments(
      String protocolId) async {
    try {
      final res = await _apiClient
          .get<Map<String, dynamic>>('/protocols/$protocolId/documents');
      final raw = (res.data?['data'] as List<dynamic>?) ?? [];
      final list = raw
          .map((e) =>
              ProtocolDocument.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<ProtocolDocument>>(
        success: true,
        message: 'OK',
        data: list,
        totalCount: list.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取方案文档失败',
      );
    }
  }

  Future<ApiResponse<ProtocolDocument>> uploadDocument({
    required String protocolId,
    required String fileName,
    required String fileExt,
    required int fileSizeBytes,
    required String version,
    String? note,
  }) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/protocols/$protocolId/documents',
        data: {
          'fileName': fileName,
          'fileExt': fileExt,
          'fileSizeBytes': fileSizeBytes,
          'version': version,
          'note': note,
        },
      );
      if (res.data == null) return ApiResponse.error(message: '上传失败');
      return ApiResponse.ok(
          message: '文档已上传',
          data: ProtocolDocument.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '上传文档失败',
      );
    }
  }
}

/// Research-centre CRUD — one record per investigator site.
class CenterService {
  final ApiClient _apiClient;
  CenterService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<ApiResponse<List<ResearchCenter>>> listCenters() async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/centers');
      final raw = (res.data?['data'] as List<dynamic>?) ??
          (res.data?['content'] as List<dynamic>?) ??
          [];
      final list = raw
          .map((e) => ResearchCenter.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<ResearchCenter>>(
        success: true,
        message: 'OK',
        data: list,
        totalCount: list.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取中心列表失败',
      );
    }
  }

  Future<ApiResponse<ResearchCenter>> getCenter(String id) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/centers/$id');
      if (res.data == null) return ApiResponse.error(message: '中心不存在');
      return ApiResponse.ok(data: ResearchCenter.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取中心失败',
      );
    }
  }

  Future<ApiResponse<ResearchCenter>> createCenter({
    required String code,
    required String name,
    required String department,
    String? address,
    String? irbNumber,
    DateTime? irbApprovalDate,
    String? leadPiName,
    String? piContact,
  }) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/centers',
        data: {
          'code': code,
          'name': name,
          'department': department,
          'address': address,
          'irbNumber': irbNumber,
          'irbApprovalDate': irbApprovalDate?.toIso8601String(),
          'leadPiName': leadPiName,
          'piContact': piContact,
        },
      );
      if (res.data == null) return ApiResponse.error(message: '创建中心失败');
      return ApiResponse.ok(
          message: '中心已创建', data: ResearchCenter.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '创建中心失败',
      );
    }
  }

  /// W6 — 编辑中心负责人 / 联系方式（PI/Admin，服务端写审计）。
  Future<ApiResponse<ResearchCenter>> updateCenter(
    String id, {
    String? leadPiName,
    String? piContact,
  }) async {
    try {
      final res = await _apiClient.put<Map<String, dynamic>>(
        '/centers/$id',
        data: {
          if (leadPiName != null) 'leadPiName': leadPiName,
          if (piContact != null) 'piContact': piContact,
        },
      );
      if (res.data == null) return ApiResponse.error(message: '更新失败');
      return ApiResponse.ok(
          message: '已保存', data: ResearchCenter.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '更新中心失败',
      );
    }
  }

  /// List the sites a protocol has been activated at.
  Future<ApiResponse<List<ProtocolCenterAllocation>>> listAllocations(
      String protocolId) async {
    try {
      final res = await _apiClient
          .get<Map<String, dynamic>>('/protocols/$protocolId/centers');
      final raw = (res.data?['data'] as List<dynamic>?) ??
          (res.data?['content'] as List<dynamic>?) ??
          [];
      final list = raw
          .map((e) => ProtocolCenterAllocation.fromJson(
              e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<ProtocolCenterAllocation>>(
        success: true,
        message: 'OK',
        data: list,
        totalCount: list.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取方案中心失败',
      );
    }
  }
}
