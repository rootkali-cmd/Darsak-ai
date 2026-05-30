import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _error;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null;
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkAuth();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _api.login(email, password);
      _token = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      final prefs = await SharedPreferences.getInstance();
      if (_token != null) {
        await prefs.setString('access_token', _token!);
      }
      if (refreshToken != null) {
        await prefs.setString('refresh_token', refreshToken);
      }

      await _loadUser();
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['detail'] ?? 'فشل تسجيل الدخول. تحقق من الاتصال.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ غير متوقع';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadUser() async {
    try {
      final data = await _api.getMe();
      _user = data;
      notifyListeners();
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    if (_token != null) {
      try {
        await _loadUser();
      } catch (e) {
        _token = null;
        _user = null;
        await prefs.remove('access_token');
        await prefs.remove('refresh_token');
      }
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }
}
