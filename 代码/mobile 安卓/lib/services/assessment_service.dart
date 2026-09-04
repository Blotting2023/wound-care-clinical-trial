import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/assessment.dart';
import 'api_client.dart';

/// Service for assessment CRUD, AI result retrieval, confirm/submit/lock operations.
class AssessmentService {
  final ApiClient _apiClient;

  AssessmentService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetch assessments for a wound.
  Future<ApiResponse<List<Assessment>>> getAssessments(String woundId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/wounds/$woundId/assessments',
      );
      final list = response.data;
      if (list != null) {
        final assessments = list
            .map((e) => Assessment.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse<List<Assessment>>(
          success: true,
          message: 'OK',
          data: assessments,
          totalCount: assessments.length,
        );
      }
      return ApiResponse.error(message: 'No assessments found');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load assessments',
      );
    }
  }

  /// Get a single assessment by ID.
  Future<ApiResponse<Assessment>> getAssessment(String assessmentId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/assessments/$assessmentId',
      );
      if (response.data != null) {
        return ApiResponse.ok(data: Assessment.fromJson(response.data!));
      }
      return ApiResponse.error(message: 'Assessment not found');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load assessment',
      );
    }
  }

  /// Create a new draft assessment.
  /// [recordTime]: 来自导入照片的 EXIF 拍摄时间；为 null 时后端用服务端时间。
  Future<ApiResponse<Assessment>> createAssessment({
    required String patientId,
    required String woundId,
    required String clinicianId,
    String? clinicianName,
    String? notes,
    DateTime? recordTime,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/assessments',
        data: {
          'patientId': patientId,
          'woundId': woundId,
          'clinicianId': clinicianId,
          'clinicianName': clinicianName,
          'notes': notes,
          if (recordTime != null)
            'createdAt': recordTime.toUtc().toIso8601String(),
        },
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Assessment created',
          data: Assessment.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to create assessment');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to create assessment',
      );
    }
  }

  /// Submit assessment for AI analysis (image URL required).
  Future<ApiResponse<Assessment>> submitForAnalysis({
    required String assessmentId,
    required String imageUrl,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/assessments/$assessmentId/analyze',
        data: {'imageUrl': imageUrl},
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'AI analysis completed',
          data: Assessment.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'AI analysis failed');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'AI analysis failed',
      );
    }
  }

  /// Confirm assessment with clinician-overridden values.
  Future<ApiResponse<Assessment>> confirmAssessment(Assessment assessment) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/assessments/${assessment.id}/confirm',
        data: assessment.toJson(),
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Assessment confirmed',
          data: Assessment.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to confirm assessment');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to confirm assessment',
      );
    }
  }

  /// Submit assessment for e-signature.
  Future<ApiResponse<Assessment>> submitForSignature(String assessmentId) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/assessments/$assessmentId/submit',
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Submitted for signature',
          data: Assessment.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to submit');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to submit',
      );
    }
  }

  /// Lock assessment with PIN/biometric signature.
  Future<ApiResponse<Assessment>> lockAssessment({
    required String assessmentId,
    required String pin,
    required String signOffMethod,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/assessments/$assessmentId/lock',
        data: {
          'pin': pin,
          'signOffMethod': signOffMethod,
        },
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Assessment locked',
          data: Assessment.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to lock assessment');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to lock assessment',
      );
    }
  }

  /// GCP W3.1 — 读评估冻结的创面照片源数据（含 sha256 + cosKey + EXIF）。
  Future<ApiResponse<Map<String, dynamic>>> getPhotoMetadata(
      String assessmentId) async {
    try {
      final resp = await _apiClient.get<Map<String, dynamic>>(
        '/assessments/$assessmentId/photo-metadata',
      );
      if (resp.data != null) {
        return ApiResponse.ok(message: 'OK', data: resp.data!);
      }
      return ApiResponse.error(message: 'No photo metadata');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Photo metadata not found',
      );
    }
  }

  /// GCP W3.2 — CRF 完成声明（PI 必签，PIN 二次鉴别）。
  Future<ApiResponse<Assessment>> declareCrfComplete({
    required String assessmentId,
    required String pin,
    required String operatorId,
    required String operatorName,
  }) async {
    try {
      final resp = await _apiClient.patch<Map<String, dynamic>>(
        '/assessments/$assessmentId/declare-crf-complete',
        data: {
          'pin': pin,
          'operatorId': operatorId,
          'operatorName': operatorName,
        },
      );
      if (resp.data != null) {
        return ApiResponse.ok(
          message: 'CRF 完成声明已记录',
          data: Assessment.fromJson(resp.data!),
        );
      }
      return ApiResponse.error(message: 'CRF 完成声明失败');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'CRF 完成声明失败',
      );
    }
  }
}
