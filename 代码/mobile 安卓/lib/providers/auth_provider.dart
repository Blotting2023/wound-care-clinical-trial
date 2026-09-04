import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  String? _userId;
  String? _displayName;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get userId => _userId;
  String? get displayName => _displayName;

  /// Restore session from secure storage on app start.
  Future<void> checkAuthOnStartup() async {
    _token = await _authService.getStoredToken();
    _userId = await _storage.read(key: 'user_id');
    _isAuthenticated = _token != null;
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
      _token = result['token'];
      _userId = result['userId'];
      _displayName = result['displayName'] ?? username;
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

  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _token = null;
    _userId = null;
    _displayName = null;
    notifyListeners();
  }
}
