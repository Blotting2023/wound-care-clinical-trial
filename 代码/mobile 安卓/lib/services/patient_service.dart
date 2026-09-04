import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/patient.dart';
import 'api_client.dart';

/// Service for patient CRUD operations against the backend API.
class PatientService {
  final ApiClient _apiClient;

  PatientService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Fetch all patients for the current facility.
  Future<ApiResponse<List<Patient>>> getPatients({
    int page = 0,
    int size = 20,
    String? search,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/patients',
        queryParameters: {
          'page': page,
          'size': size,
          if (search != null && search.isNotEmpty) 'search': search,
        },
      );

      final data = response.data;
      if (data != null) {
        final content = (data['content'] as List<dynamic>?) ??
            (data['data'] as List<dynamic>?) ??
            [];
        final patients = content
            .map((e) => Patient.fromJson(e as Map<String, dynamic>))
            .toList();
        final totalCount = data['totalElements'] as int? ?? patients.length;
        return ApiResponse<List<Patient>>(
          success: true,
          message: 'OK',
          data: patients,
          totalCount: totalCount,
        );
      }

      return ApiResponse.error(message: 'No data received');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load patients',
      );
    }
  }

  /// Get a single patient by ID.
  Future<ApiResponse<Patient>> getPatient(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/patients/$id',
      );
      if (response.data != null) {
        return ApiResponse.ok(
          data: Patient.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Patient not found');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load patient',
      );
    }
  }

  /// Create a new patient record.
  Future<ApiResponse<Patient>> createPatient({
    required String facilityId,
    required String patientCode,
    DateTime? dateOfBirth,
    String? gender,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/patients',
        data: {
          'facilityId': facilityId,
          'patientCode': patientCode,
          'dateOfBirth': dateOfBirth?.toIso8601String(),
          'gender': gender,
        },
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Patient created',
          data: Patient.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to create patient');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to create patient',
      );
    }
  }

  /// Update an existing patient record.
  Future<ApiResponse<Patient>> updatePatient(Patient patient) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/patients/${patient.id}',
        data: patient.toJson(),
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Patient updated',
          data: Patient.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Failed to update patient');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to update patient',
      );
    }
  }
}
