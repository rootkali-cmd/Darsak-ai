import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:dio/dio.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isBiometricVerified = false;
  String? _token;
  String? _lastError;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://darsak-backend.fly.dev/api/admin',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  bool get isAuthenticated => _isAuthenticated;
  bool get isBiometricVerified => _isBiometricVerified;
  bool get needsBiometric => _isAuthenticated && !_isBiometricVerified;
  String? get lastError => _lastError;

  AuthProvider() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('admin_token');
    if (_token != null) _isAuthenticated = true;
    notifyListeners();
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'الرجاء التحقق من هويتك للدخول للوحة التحكم',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      _isBiometricVerified = didAuthenticate;
      notifyListeners();
      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login(String password) async {
    _lastError = null;
    try {
      final res = await _dio.post('/login', data: {'password': password});
      final token = res.data['access_token'];
      if (token == null) {
        _lastError = 'استجابة غير صحيحة من الخادم';
        return false;
      }
      _token = token as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', _token!);
      _isAuthenticated = true;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
        _lastError = 'تعذر الاتصال بالخادم';
      } else if (e.type == DioExceptionType.connectionError) {
        _lastError = 'لا يوجد اتصال بالإنترنت';
      } else if (e.response?.statusCode == 401) {
        _lastError = 'كلمة المرور غير صحيحة';
      } else {
        _lastError = 'خطأ: ${e.response?.statusCode ?? e.message}';
      }
      return false;
    } catch (e) {
      _lastError = 'خطأ غير متوقع: $e';
      return false;
    }
  }

  void resetBiometric() {
    _isBiometricVerified = false;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _isAuthenticated = false;
    _isBiometricVerified = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_token');
    notifyListeners();
  }
}
