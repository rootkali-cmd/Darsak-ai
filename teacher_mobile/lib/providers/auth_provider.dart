import 'dart:convert';
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

  static bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(parts[1])),
      );
      final exp = payload['exp'] as int?;
      if (exp == null) return true;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return true;
    }
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

      ApiService.clearLogoutFlag();

      try {
        await _loadUser();
      } catch (_) {
        _user = {'id': '', 'full_name': ''};
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      String? detail;
      final respData = e.response?.data;
      if (respData is Map) {
        detail = respData['detail']?.toString();
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        _error = 'تعذر الاتصال بالخادم. تأكد من اتصالك وحاول مرة أخرى.';
      } else if (e.response?.statusCode == 401) {
        _error = detail ?? 'بيانات الدخول غير صحيحة.';
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

    if (_token == null || _token!.isEmpty) {
      notifyListeners();
      return;
    }

    final tokenExpired = _isTokenExpired(_token!);

    if (tokenExpired) {
      _token = null;
      _user = null;
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
      notifyListeners();
      return;
    }

    // Try to ping the server first to wake it up from cold start
    try {
      await _api.ping();
    } catch (_) {
      // ignore ping failures, continue to try _loadUser
    }

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        await _loadUser();
        ApiService.clearLogoutFlag();
        break;
      } catch (e) {
        if (e is DioException && e.response?.statusCode == 401) {
          _user = _extractUserFromToken(_token!);
          if (_user == null) {
            _token = null;
            await prefs.remove('access_token');
            await prefs.remove('refresh_token');
          }
          break;
        }
        // Connection error (cold start) — retry once after delay
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: 3));
          continue;
        }
        // Second attempt failed too — extract from JWT as fallback
        _user = _extractUserFromToken(_token!);
      }
    }

    notifyListeners();
  }

  static Map<String, dynamic>? _extractUserFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(parts[1])),
      );
      return {
        'id': payload['sub'],
        'full_name': payload['name'] ?? '',
      };
    } catch (_) {
      return null;
    }
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
