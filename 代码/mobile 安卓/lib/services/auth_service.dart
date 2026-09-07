import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import 'api_client.dart';
import 'app_secure_storage.dart';

/// Authentication service handling login, logout, token storage,
/// biometric unlock, and signature PIN management.
class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;

  AuthService({
    ApiClient? apiClient,
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuth,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _secureStorage = secureStorage ?? appSecureStorage,
        _localAuth = localAuth ?? LocalAuthentication();

  /// Authenticate with username and password.
  /// Returns a map with [token], [user], [userId] and [displayName] on success.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    String? serverUrl,
  }) async {
    if (serverUrl != null && serverUrl.isNotEmpty) {
      _apiClient.updateBaseUrl(serverUrl);
    }
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
    );

    final data = response.data;
    if (data != null && data['token'] != null) {
      final token = data['token'] as String;
      await _apiClient.setToken(token);
      final userJson = data['user'] as Map<String, dynamic>?;
      final user = userJson != null
          ? User.fromJson(userJson)
          : User(
              id: data['userId'] as String? ?? '',
              username: username,
              displayName: data['displayName'] as String? ?? username,
              role: UserRole.tryParse(data['role'] as String?) ?? UserRole.CRC,
            );
      if (user.id.isNotEmpty && !ApiConfig.demoMode) {
        await _secureStorage.write(key: 'user_id', value: user.id);
      }
      return {
        'token': token,
        'user': user,
        'userId': user.id,
        'displayName': user.displayName,
        'role': user.role.name,
      };
    }
    throw Exception(data?['message'] as String? ?? 'Invalid response from server');
  }

  /// V1 demo 专属：切换演示角色（不走重新登录）。
  /// 生产环境禁止暴露此端点。
  Future<User> switchDemoRole(String roleName) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/switch-demo-role',
      data: {'role': roleName},
    );
    final data = response.data;
    final userJson = data?['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw Exception('切换角色失败：返回空');
    }
    return User.fromJson(userJson);
  }

  /// 拉取当前用户（从服务端，主要是 dev 阶段校验）
  Future<User> fetchCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/auth/me');
    return User.fromJson(response.data ?? {});
  }

  /// Logout: clear token and local data.
  Future<void> logout() async {
    await _apiClient.clearToken();
    if (!ApiConfig.demoMode) {
      await _secureStorage.deleteAll();
    }
  }

  /// Retrieve the stored JWT token.
  Future<String?> getStoredToken() async {
    return _apiClient.loadToken();
  }

  /// Check if biometric authentication is available on this device.
  Future<bool> isBiometricAvailable() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final supported = await _localAuth.isDeviceSupported();
    return canCheck && supported;
  }

  /// Get a list of available biometric types.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    return _localAuth.getAvailableBiometrics();
  }

  /// Perform biometric authentication (fingerprint / face).
  Future<bool> biometricAuthenticate({required String reason}) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Change the signature PIN (requires current password for verification).
  Future<bool> changeSignaturePin({
    required String oldPassword,
    required String newPin,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/change-pin',
      data: {'oldPassword': oldPassword, 'newPin': newPin},
    );
    return response.data?['success'] == true;
  }

  /// Lock an assessment with the signature PIN (demo: any 6-digit PIN works).
  Future<void> lockAssessment({
    required String assessmentId,
    required String pin,
    required String meaning,
  }) async {
    await _apiClient.post<Map<String, dynamic>>(
      '/assessments/$assessmentId/lock',
      data: {'pin': pin, 'signOffMethod': 'pin', 'signatureMeaning': meaning},
    );
  }

  /// Store the server URL in secure storage.
  Future<void> setServerUrl(String url) async {
    await _secureStorage.write(key: 'server_url', value: url);
    _apiClient.updateBaseUrl(url);
  }

  /// Retrieve the stored server URL.
  Future<String?> getServerUrl() async {
    return _secureStorage.read(key: 'server_url');
  }
}
