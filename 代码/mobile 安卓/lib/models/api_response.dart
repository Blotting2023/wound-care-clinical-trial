/// Generic API response wrapper matching the Spring Boot backend format.
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<String>? errors;
  final int? totalCount;

  const ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.totalCount,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    required T Function(dynamic json)? fromJsonT,
  }) {
    return ApiResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : null,
      errors: json['errors'] != null
          ? List<String>.from(json['errors'] as List)
          : null,
      totalCount: json['totalCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'data': data,
      'errors': errors,
      'totalCount': totalCount,
    };
  }

  /// Convenience: an empty success response.
  factory ApiResponse.ok({String message = 'OK', T? data}) {
    return ApiResponse(success: true, message: message, data: data);
  }

  /// Convenience: an error response.
  factory ApiResponse.error({required String message, List<String>? errors}) {
    return ApiResponse(success: false, message: message, errors: errors);
  }
}
