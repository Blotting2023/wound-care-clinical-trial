import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/wound.dart';
import 'api_client.dart';

/// Service for wound CRUD operations.
class WoundService {
  final ApiClient _apiClient;

  WoundService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetch all wounds for a given patient.
  Future<ApiResponse<List<Wound>>> getWounds(String patientId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/patients/$patientId/wounds',
      );
      final list = response.data;
      if (list != null) {
        final wounds = list
            .map((e) => Wound.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse<List<Wound>>(
          success: true,
          message: 'OK',
          data: wounds,
          totalCount: wounds.length,
        );
      }
      return ApiResponse.error(message: 'No wounds found');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load wounds',
      );
    }
  }

  /// Get a single wound by ID.
  Future<ApiResponse<Wound>> getWound(String woundId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/wounds/$woundId',
      );
      if (response.data != null) {
        return ApiResponse.ok(data: Wound.fromJson(response.data!));
      }
      return ApiResponse.error(message: 'Wound not found');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load wound',
      );
    }
  }

  /// Create a new wound for a patient.
  Future<ApiResponse<Wound>> createWound({
    required String patientId,
    required String anatomicalLocation,
    String? woundType,
    String? etiology,
    required DateTime onsetDate,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/patients/$patientId/wounds',
        data: {
          'patientId': patientId,
          'anatomicalLocation': anatomicalLocation,
          'woundType': woundType,
          'etiology': etiology,
          'onsetDate': onsetDate.toIso8601String(),
        },
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Wound created',
          data: Wound.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to create wound');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to create wound',
      );
    }
  }

  /// Update an existing wound.
  Future<ApiResponse<Wound>> updateWound(Wound wound) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/wounds/${wound.id}',
        data: wound.toJson(),
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Wound updated',
          data: Wound.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to update wound');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to update wound',
      );
    }
  }
}
