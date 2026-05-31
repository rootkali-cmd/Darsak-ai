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
  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _user != null;
  bool get hasToken => _token != null && _token!.isNotEmpty;
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

      if (_token == null || _token!.isEmpty) {
        _error = 'بيانات الدخول غير صحيحة.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _token!);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
      }

      try {
        await _loadUser();
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      String? detail;
      final data = e.response?.data;
      if (data is Map) {
        detail = data['detail']?.toString();
      }
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        _error = 'تعذر الاتصال بالخادم. تأكد من اتصالك وحاول مرة أخرى.';
      } else if (e.response?.statusCode == 401) {
        _error = detail ?? 'بيانات الدخول غير صحيحة.';
      } else if (e.response?.statusCode == 307 || e.response?.statusCode == 302) {
        _error = 'خطأ في الاتصال. حاول مرة أخرى.';
      } else {
        _error = detail ?? 'فشل تسجيل الدخول. تحقق من البيانات.';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadUser() async {
    final data = await _api.getMe();
    _user = data;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');

    if (_token != null && _token!.isNotEmpty) {
      try {
        await _loadUser();
      } catch (e) {
        // If getMe() failed, check if interceptor refreshed the token
        final updatedToken = prefs.getString('access_token');
        if (updatedToken != null && updatedToken != _token) {
          _token = updatedToken;
          try {
            await _loadUser();
          } catch (_) {}
        }
        // Don't clear tokens on network errors — keep user authenticated
        // User data will load on next screen
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
