import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/api_response.dart';
import '../models/assessment_image.dart';
import '../models/photo_metadata.dart';
import 'api_client.dart';

/// Service for assessment image upload and management.
class ImageService {
  final ApiClient _apiClient;

  ImageService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Upload an assessment image to the server.
  Future<ApiResponse<AssessmentImage>> uploadImage({
    required String assessmentId,
    required String filePath,
    required String imageType,
    void Function(int, int)? onProgress,
  }) async {
    try {
      final response = await _apiClient.uploadFile<Map<String, dynamic>>(
        '/assessments/$assessmentId/images',
        filePath: filePath,
        fieldName: 'file',
        extraFields: {'imageType': imageType},
        onSendProgress: onProgress,
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: 'Image uploaded',
          data: AssessmentImage.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: 'Image upload failed');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Image upload failed',
      );
    }
  }

  /// GCP W3.1 — 把创面照片源数据（SHA256 + EXIF + 设备指纹）落到评估。
  ///
  /// V1 demo 阶段用 multipart extraFields 把 [metadata] 的 JSON 字符串
  /// 跟 imageType 一起塞进 multipart 表单。真实阶段换成独立 JSON POST。
  Future<ApiResponse<AssessmentImage>> uploadPhotoMetadata({
    required String assessmentId,
    required PhotoMetadata metadata,
  }) async {
    try {
      final response = await _apiClient.uploadFile<Map<String, dynamic>>(
        '/assessments/$assessmentId/images',
        filePath: _stubFilePath(metadata), // demo: 不真上传文件
        fieldName: 'file',
        extraFields: {
          'imageType': 'woundCapture',
          'metadata': jsonEncode(metadata.toJson()),
        },
      );
      if (response.data != null) {
        return ApiResponse.ok(
          message: '创面照片源数据已落库',
          data: AssessmentImage.fromJson(response.data!),
        );
      }
      return ApiResponse.error(message: '创面照片源数据上传失败');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ??
            '创面照片源数据上传失败',
      );
    }
  }

  /// demo 阶段：multipart 需要一个真实文件路径；传一个 0 字节占位即可。
  /// (DemoBackend 在 onRequest 层不读 multipart 实际文件，只解析 metadata.)
  String _stubFilePath(PhotoMetadata metadata) {
    return '/tmp/${metadata.cosKey.split('/').last}';
  }

  /// Get all images for an assessment.
  Future<ApiResponse<List<AssessmentImage>>> getImages(String assessmentId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/assessments/$assessmentId/images',
      );
      final list = response.data;
      if (list != null) {
        final images = list
            .map((e) => AssessmentImage.fromJson(e as Map<String, dynamic>))
            .toList();
        return ApiResponse<List<AssessmentImage>>(
          success: true,
          message: 'OK',
          data: images,
          totalCount: images.length,
        );
      }
      return ApiResponse.error(message: 'No images found');
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to load images',
      );
    }
  }

  /// Delete an image from the server.
  Future<ApiResponse<bool>> deleteImage(String imageId) async {
    try {
      await _apiClient.delete<dynamic>('/assessment-images/$imageId');
      return ApiResponse.ok(message: 'Image deleted', data: true);
    } on DioException catch (e) {
      return ApiResponse.error(
        message: e.response?.data?['message'] as String? ?? 'Failed to delete image',
      );
    }
  }
}
