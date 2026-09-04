import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'app_secure_storage.dart';
import 'demo_backend.dart';

/// Dio HTTP client with JWT auth interceptor and offline retry support.
///
/// A single shared instance ([ApiClient.instance]) is used across the whole
/// app so the token and demo backend stay consistent.
class ApiClient {
  ApiClient({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? appSecureStorage {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    if (ApiConfig.demoMode) {
      _dio.interceptors.add(DemoBackend());
    }

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));
  }

  /// App-wide shared client.
  static final ApiClient instance = ApiClient();

  late final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  String? _token;

  /// Callback invoked when a 401 is received (force logout).
  void Function()? onUnauthorized;

  /// Callback invoked when a network error occurs (queue for offline).
  void Function(DioException error)? onNetworkError;

  /// Main Dio instance for use by services.
  Dio get dio => _dio;

  /// Current auth token (may be null before login).
  String? get token => _token;

  /// Update the base URL at runtime (from settings).
  void updateBaseUrl(String url) {
    ApiConfig.baseUrl = url;
    _dio.options.baseUrl = url;
  }

  /// Set the auth token and persist it (memory-only in demo mode).
  Future<void> setToken(String token) async {
    _token = token;
    if (ApiConfig.demoMode) return; // demo: no keychain dependency
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  /// Load token from secure storage on app start.
  Future<String?> loadToken() async {
    if (ApiConfig.demoMode) return _token;
    _token = await _secureStorage.read(key: 'jwt_token');
    return _token;
  }

  /// Clear stored token.
  Future<void> clearToken() async {
    _token = null;
    if (ApiConfig.demoMode) return; // demo: no keychain dependency
    await _secureStorage.delete(key: 'jwt_token');
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_token != null && !ApiConfig.demoMode) {
      options.headers['Authorization'] = 'Bearer $_token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (error.response?.statusCode == 401 && !ApiConfig.demoMode) {
      // Unauthorized — trigger logout
      await clearToken();
      onUnauthorized?.call();
    } else if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      // Network error — notify offline queue
      onNetworkError?.call(error);
    }
    handler.next(error);
  }

  /// Convenience: perform a GET request with retry.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _withRetry(
      () => _dio.get<T>(path, queryParameters: queryParameters, options: options),
    );
  }

  /// Convenience: perform a POST request with retry.
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _withRetry(
      () => _dio.post<T>(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  /// Convenience: perform a PUT request with retry.
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _withRetry(
      () => _dio.put<T>(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  /// Convenience: perform a DELETE request with retry.
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _withRetry(
      () => _dio.delete<T>(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  /// Convenience: perform a PATCH request with retry.
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _withRetry(
      () => _dio.patch<T>(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  /// Upload a file with multipart form data.
  Future<Response<T>> uploadFile<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? extraFields,
    void Function(int, int)? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
      if (extraFields != null) ...extraFields,
    });
    return _withRetry(
      () => _dio.post<T>(path,
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}),
          onSendProgress: onSendProgress),
    );
  }

  Future<Response<T>> _withRetry<T>(
    Future<Response<T>> Function() request,
  ) async {
    int attempts = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        attempts++;
        if (attempts >= ApiConfig.maxRetries) rethrow;
        if (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout) {
          await Future.delayed(
            Duration(seconds: attempts * 2),
          ); // exponential backoff
          continue;
        }
        rethrow;
      }
    }
  }
}
