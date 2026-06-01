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
  Map<String, dynamic>? get user => _user;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    await checkAuth();
  }

  static Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final padded = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
      final payload = jsonDecode(utf8.decode(base64Url.decode(padded)));
      final sub = payload['sub'];
      if (sub == null) return null;
      final exp = payload['exp'] as int?;
      final expired = exp != null &&
          DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
      return {
        'id': sub.toString(),
        'full_name': payload['name']?.toString() ?? '',
        'expired': expired,
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

      final jwt = _parseJwt(_token!);
      if (jwt != null) {
        _user = {'id': jwt['id'], 'full_name': jwt['full_name']};
      } else {
        _user = {'id': '', 'full_name': ''};
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _handleLoginError(e);
      return false;
    } catch (e) {
      _error = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void _handleLoginError(DioException e) {
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
    } else if (e.response?.statusCode == 500) {
      _error = 'خطأ في الخادم. حاول مرة أخرى لاحقاً.';
    } else {
      _error = detail ?? 'فشل تسجيل الدخول. تحقق من البيانات.';
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');

    if (_token == null || _token!.isEmpty) {
      notifyListeners();
      return;
    }

    final jwt = _parseJwt(_token!);
    if (jwt == null || jwt['id'] == null || jwt['id'].toString().isEmpty) {
      await _clearToken(prefs);
      notifyListeners();
      return;
    }

    if (jwt['expired'] == true) {
      await _clearToken(prefs);
      notifyListeners();
      return;
    }

    _user = {'id': jwt['id'], 'full_name': jwt['full_name']};
    notifyListeners();
  }

  Future<void> _clearToken(SharedPreferences prefs) async {
    _token = null;
    _user = null;
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await _clearToken(prefs);
    notifyListeners();
  }
}
