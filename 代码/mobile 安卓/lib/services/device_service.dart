import 'package:dio/dio.dart';

import '../models/api_response.dart';
import '../models/investigational_device.dart';
import '../models/device_usage_log.dart';
import 'api_client.dart';

/// Investigational-device CRUD — managed lot/serial inventory for GCP §22.
class DeviceService {
  final ApiClient _apiClient;
  DeviceService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<ApiResponse<List<InvestigationalDevice>>> listDevices({
    String? status,
    String? centerId,
  }) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/devices',
        queryParameters: {
          if (status != null) 'status': status,
          if (centerId != null) 'centerId': centerId,
        },
      );
      final raw = (res.data?['data'] as List<dynamic>?) ??
          (res.data?['content'] as List<dynamic>?) ??
          [];
      final list = raw
          .map((e) => InvestigationalDevice.fromJson(
              e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<InvestigationalDevice>>(
        success: true,
        message: 'OK',
        data: list,
        totalCount: list.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取器械库存失败',
      );
    }
  }

  Future<ApiResponse<InvestigationalDevice>> getDevice(String id) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>('/devices/$id');
      if (res.data == null) return ApiResponse.error(message: '器械不存在');
      return ApiResponse.ok(data: InvestigationalDevice.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取器械失败',
      );
    }
  }

  Future<ApiResponse<InvestigationalDevice>> createDevice({
    required String deviceType,
    required String modelName,
    required String manufacturer,
    required String lotNumber,
    required String serialNumber,
    required DateTime manufactureDate,
    DateTime? expiryDate,
    String? qcPassedAt,
    String currentCenterId = 'f1',
    String? protocolId,
  }) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/devices',
        data: {
          'deviceType': deviceType,
          'modelName': modelName,
          'manufacturer': manufacturer,
          'lotNumber': lotNumber,
          'serialNumber': serialNumber,
          'manufactureDate': manufactureDate.toIso8601String(),
          'expiryDate': expiryDate?.toIso8601String(),
          'qcPassedAt': qcPassedAt,
          'currentCenterId': currentCenterId,
          'protocolId': protocolId,
        },
      );
      if (res.data == null) return ApiResponse.error(message: '创建器械失败');
      return ApiResponse.ok(
          message: '器械已入库', data: InvestigationalDevice.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '创建器械失败',
      );
    }
  }

  /// Mark a device returned to its centre (intact / partial / damaged).
  Future<ApiResponse<InvestigationalDevice>> returnDevice({
    required String deviceId,
    required String condition,
    String? disposalReason,
  }) async {
    try {
      final res = await _apiClient.post<Map<String, dynamic>>(
        '/devices/$deviceId/return',
        data: {
          'condition': condition,
          'disposalReason': disposalReason,
        },
      );
      if (res.data == null) {
        return ApiResponse.error(message: '归还器械失败');
      }
      return ApiResponse.ok(
          message: '器械已归还', data: InvestigationalDevice.fromJson(res.data!));
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '归还器械失败',
      );
    }
  }

  /// Usage log per subject — GCP §2022 第28号 第22条 要求可追溯.
  Future<ApiResponse<List<DeviceUsageLog>>> listUsageLogs({
    String? deviceId,
    String? patientId,
    String? protocolId,
  }) async {
    try {
      final res = await _apiClient.get<Map<String, dynamic>>(
        '/device-usage-logs',
        queryParameters: {
          if (deviceId != null) 'deviceId': deviceId,
          if (patientId != null) 'patientId': patientId,
          if (protocolId != null) 'protocolId': protocolId,
        },
      );
      final raw = (res.data?['data'] as List<dynamic>?) ??
          (res.data?['content'] as List<dynamic>?) ??
          [];
      final list = raw
          .map((e) => DeviceUsageLog.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse<List<DeviceUsageLog>>(
        success: true,
        message: 'OK',
        data: list,
        totalCount: list.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '获取使用台账失败',
      );
    }
  }
}
