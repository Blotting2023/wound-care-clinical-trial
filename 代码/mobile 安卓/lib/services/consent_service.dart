/// ConsentService — 知情同意书的 CRUD + 撤回。
///
/// V1 demo 阶段直接走 `ApiClient` HTTP 调用。生产环境应把 eConsent 签名
/// 走 KMS + COS 落地（见 W4.2）。
library;

import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/consent_form.dart';
import 'api_client.dart';

class ConsentService {
  final ApiClient _apiClient;
  ConsentService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// 查询某患者的全部 consent 记录（按时间倒序）。
  Future<ApiResponse<List<ConsentForm>>> listByPatient(String patientId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/consents/patient/$patientId',
      );
      final list = response.data ?? [];
      final items = list
          .map((e) => ConsentForm.fromJson(e as Map<String, dynamic>))
          .toList();
      return ApiResponse(
        success: true,
        message: 'OK',
        data: items,
        totalCount: items.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '查询失败',
      );
    }
  }

  /// W4.6 — IRB / Sponsor / Admin 用：列出全部 consent 记录。
  /// [status]: 可选过滤，如 'pending' 表示"未撤回 + (A通道 或 B通道已审)"。
  /// 返回的元素 subjectCode 字段就是鉴认代码（IRB 视图必备）。
  Future<ApiResponse<List<Map<String, dynamic>>>> listAll({
    String? status,
    String? centerId,
  }) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/consents',
        queryParameters: {
          if (status != null) 'status': status,
          if (centerId != null) 'centerId': centerId,
        },
      );
      final list = response.data ?? [];
      final items = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return ApiResponse(
        success: true,
        message: 'OK',
        data: items,
        totalCount: items.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '查询失败',
      );
    }
  }

  /// 创建 consent — A / B 通道都走这个端点，body.mode 区分。
  Future<ApiResponse<ConsentForm>> create({
    required String patientId,
    required String protocolId,
    String? centerId,
    String version = '1.0',
    required ConsentMode mode,
    required String signedBy,
    String? signedByName,
    // A 通道
    String? pdfPath,
    String? signaturePath,
    String? signatureStrokeJson,
    String? deviceFingerprint,
    String? operatorIp,
    // B 通道
    String? signedPaperPath,
    DateTime? paperSignedDate,
    String? witnessName,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/consents',
        data: {
          'patientId': patientId,
          'protocolId': protocolId,
          'centerId': centerId,
          'version': version,
          'mode': mode.name,
          'signedBy': signedBy,
          'signedByName': signedByName,
          'pdfPath': pdfPath,
          'signaturePath': signaturePath,
          'signatureStrokeJson': signatureStrokeJson,
          'deviceFingerprint': deviceFingerprint,
          'operatorIp': operatorIp,
          'signedPaperPath': signedPaperPath,
          'paperSignedDate': paperSignedDate?.toIso8601String(),
          'witnessName': witnessName,
        },
      );
      final data = response.data;
      if (data != null) {
        return ApiResponse.ok(
          message: '知情同意书已记录',
          data: ConsentForm.fromJson(data),
        );
      }
      return ApiResponse.error(message: '返回为空');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '创建失败',
      );
    }
  }

  /// 撤回 consent（PI / IRB / Admin 可操作）
  Future<ApiResponse<ConsentForm>> withdraw({
    required String consentId,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/consents/$consentId/withdraw',
        data: {'reason': reason},
      );
      final data = response.data;
      if (data != null) {
        return ApiResponse.ok(
          message: '已撤回',
          data: ConsentForm.fromJson(data),
        );
      }
      return ApiResponse.error(message: '撤回失败');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '撤回失败',
      );
    }
  }

  /// B 通道 PI 审核
  Future<ApiResponse<ConsentForm>> reviewPaperConsent({
    required String consentId,
    required String note,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/consents/$consentId/review',
        data: {'note': note},
      );
      final data = response.data;
      if (data != null) {
        return ApiResponse.ok(
          message: '审核完成',
          data: ConsentForm.fromJson(data),
        );
      }
      return ApiResponse.error(message: '审核失败');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '审核失败',
      );
    }
  }

  /// 切换中心 consentMode（Admin 专属）
  Future<ApiResponse<bool>> setCenterConsentMode({
    required String centerId,
    required ConsentMode mode,
  }) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/centers/$centerId/consent-mode',
        data: {'mode': mode.name},
      );
      return response.data != null
          ? ApiResponse.ok(message: '已切换', data: true)
          : ApiResponse.error(message: '切换失败');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '切换失败',
      );
    }
  }

  /// 列出全部中心 + 当前 consentMode（给 admin 切换页用）
  Future<ApiResponse<List<ConsentModeCenterInfo>>> listCentersWithMode() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/centers?withConsentMode=true',
      );
      final list = response.data ?? [];
      final items = list
          .map((e) => ConsentModeCenterInfo.fromJson(
              e as Map<String, dynamic>))
          .toList();
      return ApiResponse(
        success: true,
        message: 'OK',
        data: items,
        totalCount: items.length,
      );
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? '查询失败',
      );
    }
  }
}

/// 简化的中心+consentMode 视图（admin 切换页用）
class ConsentModeCenterInfo {
  final String id;
  final String name;
  final String code;
  final ConsentMode mode;
  final DateTime? modeSetAt;
  final String? modeSetBy;
  const ConsentModeCenterInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.mode,
    this.modeSetAt,
    this.modeSetBy,
  });
  factory ConsentModeCenterInfo.fromJson(Map<String, dynamic> json) =>
      ConsentModeCenterInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        mode: ConsentMode.tryParse(json['consentMode'] as String?) ??
            ConsentMode.PAPER_PHOTO,
        modeSetAt: json['consentModeSetAt'] != null
            ? DateTime.parse(json['consentModeSetAt'] as String)
            : null,
        modeSetBy: json['consentModeSetBy'] as String?,
      );
}
