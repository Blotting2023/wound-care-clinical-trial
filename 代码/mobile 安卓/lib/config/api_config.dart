/// API configuration for the wound assessment system.
/// Base URL and timeout settings are configurable at runtime via settings.
class ApiConfig {
  /// Default base URL for the Spring Boot backend.
  /// Overridable via the settings screen.
  static String baseUrl = 'http://localhost:8080/api';

  /// Demo mode: when true, all API calls are answered by the built-in
  /// in-memory demo backend so the app can be explored without a server.
  static bool demoMode = true;

  /// Connection timeout duration.
  static const Duration connectTimeout = Duration(seconds: 10);

  /// Receive timeout for large payloads (image uploads).
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Maximum retry attempts for failed requests.
  static const int maxRetries = 3;

  /// Maximum image dimension for upload compression (long edge).
  static const int imageMaxDimension = 1920;

  /// JPEG compression quality (0-100).
  static const int imageQuality = 85;

  /// Private constructor to prevent instantiation.
  const ApiConfig._();
}
