import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _tokenKey = 'access_token';

  bool _isLoading = false;
  String? _error;
  String? _token;
  Map<String, dynamic>? _user;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _user != null;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      _token = await _storage.read(key: _tokenKey);
    } catch (_) {}
    if (_token != null && _token!.isNotEmpty) {
      final jwt = _parseJwt(_token!);
      if (jwt != null && jwt['expired'] != true && jwt['id'] != null) {
        _user = {'id': jwt['id'], 'full_name': jwt['full_name'] ?? ''};
      } else {
        await _storage.delete(key: _tokenKey);
        _token = null;
      }
    }
    _isLoading = false;
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

      final data = await _api.login(email, password);
      final newToken = data['access_token'] as String?;

      if (newToken == null || newToken.isEmpty) {
        _error = 'بيانات الدخول غير صحيحة';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _token = newToken;
      await _storage.write(key: _tokenKey, value: _token);

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
      _error = 'حدث خطأ غير متوقع';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  String _getDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'تعذر الاتصال بالخادم. تأكد من اتصالك';
    }
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    if (e.response?.statusCode == 401) {
      return 'بيانات الدخول غير صحيحة';
    }
    return 'فشل تسجيل الدخول. حاول مرة أخرى';
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
    notifyListeners();
  }
}
