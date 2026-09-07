import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../models/user_role.dart';
import '../services/app_secure_storage.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthService? authService, FlutterSecureStorage? storage})
      : _authService = authService ?? AuthService(),
        _storage = storage ?? appSecureStorage;

  final AuthService _authService;
  final FlutterSecureStorage _storage;

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _token;
  User? _user;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get userId => _user?.id;
  String? get displayName => _user?.displayName;

  /// 当前登录用户（V1 demo 阶段永远非空，登录后即填充）
  User? get user => _user;

  UserRole? get role => _user?.role;

  /// Restore session from secure storage on app start.
  Future<void> checkAuthOnStartup() async {
    _token = await _authService.getStoredToken();
    final storedId = await _storage.read(key: 'user_id');
    _isAuthenticated = _token != null;
    if (_isAuthenticated && storedId != null) {
      // 恢复默认 CRC（实际场景应从 token 解析）
      _user = User(
        id: storedId,
        username: storedId,
        displayName: '已恢复会话',
        role: UserRole.CRC,
      );
    }
    notifyListeners();
  }

  /// Login and persist the session. Throws on failure.
  Future<bool> login(String username, String password, String serverUrl) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _authService.login(
        username: username,
        password: password,
        serverUrl: serverUrl,
      );
      _token = result['token'] as String?;
      _user = result['user'] as User?;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// V1 demo 专属：切换演示角色（settings_screen 头部入口调用）
  Future<void> switchDemoRole(UserRole role) async {
    final u = await _authService.switchDemoRole(role.name);
    _user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _token = null;
    _user = null;
    notifyListeners();
  }
}
