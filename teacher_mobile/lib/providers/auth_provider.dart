import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  static const _tokenKey = 'access_token';
  static const _rfreshKey = 'refresh_token';

  bool _isLoading = false;
  String? _error;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _user != null;
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    if (_token != null && _token!.isNotEmpty) {
      final jwt = _parseJwt(_token!);
      if (jwt != null && jwt['expired'] != true && jwt['id'] != null) {
        _user = {'id': jwt['id'], 'full_name': jwt['full_name'] ?? ''};
      } else {
        await prefs.remove(_tokenKey);
        await prefs.remove(_rfreshKey);
        _token = null;
      }
    }
    notifyListeners();
  }

  static Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final padded = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
      final payload = jsonDecode(utf8.decode(base64Url.decode(padded)));
      final exp = payload['exp'] as int?;
      return {
        'id': payload['sub']?.toString(),
        'full_name': payload['name']?.toString() ?? '',
        'expired': exp != null && DateTime.now().isAfter(
          DateTime.fromMillisecondsSinceEpoch(exp * 1000),
        ),
      };
    } catch (_) {
      return null;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _error = 'جاري الاتصال بالخادم...';
      notifyListeners();

      Map<String, dynamic>? data;
      DioException? lastError;

      for (int i = 0; i < 3; i++) {
        try {
          data = await _api.login(email, password);
          break;
        } on DioException catch (e) {
          lastError = e;
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          rethrow;
        }
      }

      if (data == null) {
        _error = _getDioError(lastError!);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final newToken = data['access_token'] as String?;
      final refreshToken = data['refresh_token'] as String?;

      if (newToken == null || newToken.isEmpty) {
        _error = 'بيانات الدخول غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, newToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString(_rfreshKey, refreshToken);
      }

      _token = newToken;

      final jwt = _parseJwt(_token!);
      _user = jwt != null
          ? {'id': jwt['id'], 'full_name': jwt['full_name']}
          : {'id': '', 'full_name': email};

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = _getDioError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'حدث خطأ غير متوقع: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getDioError(DioException e) {
    final type = e.type.name;
    final statusCode = e.response?.statusCode;
    final msg = e.message ?? '';
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'تعذر الاتصال ($type). تأكد من اتصالك بالإنترنت';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'خطأ اتصال ($type): $msg';
    }
    if (statusCode == 401) {
      return 'بيانات الدخول غير صحيحة';
    }
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return 'خطأ $statusCode: $msg';
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_rfreshKey);
    } catch (_) {}
    notifyListeners();
  }
}
