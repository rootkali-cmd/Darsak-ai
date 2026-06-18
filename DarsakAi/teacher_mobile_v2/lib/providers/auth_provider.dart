import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/subscription_token_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  static const _tokenKey = 'access_token';
  static const _onboardingKey = 'onboarding_completed';
  static const _baseUrl = 'https://darsak-backend.fly.dev/api';

  bool _isLoading = false;
  String? _error;
  String? _token;
  Map<String, dynamic>? _user;
  Map<String, dynamic>? _subscription;
  bool _isInitialized = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty && _user != null;
  Map<String, dynamic>? get user => _user;
  bool get isInitialized => _isInitialized;
  bool get needsOnboarding => _user != null && _user!['onboarding_completed'] != true;
  Map<String, dynamic>? get subscription => _subscription;
  bool get hasSubscription => _subscription != null;
  String? get planName => _subscription?['plan_name'];

  AuthProvider() { _init(); }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    
    // Load cached subscription immediately
    final cachedSub = prefs.getString('subscription_cache');
    if (cachedSub != null) {
      try { _subscription = jsonDecode(cachedSub); } catch (_) {}
    }
    
    if (_token != null && _token!.isNotEmpty) {
      final jwt = _parseJwt(_token!);
      if (jwt != null && jwt['expired'] != true && jwt['id'] != null) {
        _user = {'id': jwt['id'], 'full_name': jwt['full_name'] ?? ''};
        _user!['onboarding_completed'] = prefs.getBool(_onboardingKey) ?? true;
      } else if (jwt != null && jwt['expired'] == true) {
        final rt = prefs.getString('refresh_token');
        if (rt != null && rt.isNotEmpty) {
          try {
            final refreshDio = Dio(BaseOptions(
              baseUrl: _baseUrl, connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 15),
              headers: {'Content-Type': 'application/json'},
            ));
            final resp = await refreshDio.post('/auth/refresh', data: {'refresh_token': rt});
            final newAccess = resp.data['access_token'] as String?;
            final newRefresh = resp.data['refresh_token'] as String?;
            if (newAccess != null && newAccess.isNotEmpty) {
              await prefs.setString(_tokenKey, newAccess);
              _token = newAccess;
              if (newRefresh != null && newRefresh.isNotEmpty) {
                await prefs.setString('refresh_token', newRefresh);
              }
              final newJwt = _parseJwt(_token!);
              if (newJwt != null && newJwt['expired'] != true && newJwt['id'] != null) {
                _user = {'id': newJwt['id'], 'full_name': newJwt['full_name'] ?? ''};
                _user!['onboarding_completed'] = prefs.getBool(_onboardingKey) ?? true;
              }
            }
          } catch (_) {}
        }
        if (_user == null) {
          await prefs.remove(_tokenKey);
          _token = null;
        }
      } else {
        await prefs.remove(_tokenKey);
        _token = null;
      }
    }
    _isInitialized = true;
    notifyListeners();
    refreshSubscription();
  }

  static Map<String, dynamic>? _parseJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final padded = parts[1].padRight((parts[1].length + 3) ~/ 4 * 4, '=');
      final payload = jsonDecode(utf8.decode(base64Url.decode(padded)));
      final sub = payload['sub']; if (sub == null) return null;
      final exp = payload['exp'];
      return {
        'id': sub.toString(),
        'full_name': (payload['name'] ?? payload['full_name'] ?? '').toString(),
        'expired': exp is int && DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000)),
      };
    } catch (_) { return null; }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true; _error = null; notifyListeners();
    try {
      _error = 'جاري الاتصال بالخادم...'; notifyListeners();
      Map<String, dynamic>? data; DioException? lastErr;
      for (int i = 0; i < 3; i++) {
        try { data = await _api.login(email, password); break; }
        on DioException catch (e) {
          lastErr = e;
          if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            await Future.delayed(const Duration(seconds: 2)); continue;
          } rethrow;
        }
      }
      if (data == null) { _error = _getDioError(lastErr!); _isLoading = false; notifyListeners(); return false; }
      final newToken = data['access_token'] as String?;
      if (newToken == null || newToken.isEmpty) { _error = 'بيانات الدخول غير صحيحة'; _isLoading = false; notifyListeners(); return false; }
      final prefs = await SharedPreferences.getInstance(); await prefs.setString(_tokenKey, newToken);
      _token = newToken;
      final jwt = _parseJwt(_token!);
      _user = jwt != null ? {'id': jwt['id'], 'full_name': jwt['full_name'] ?? ''} : {'id': '', 'full_name': email};
      final onboardingCompleted = data['onboarding_completed'] ?? data['user']?['onboarding_completed'] ?? jwt?['onboarding_completed'];
      if (onboardingCompleted != null) {
        _user!['onboarding_completed'] = onboardingCompleted == true || onboardingCompleted == 'true';
        await prefs.setBool(_onboardingKey, _user!['onboarding_completed']!);
      } else {
        try {
          final meData = await _api.getMe();
          final serverOnboarding = meData['onboarding_completed'];
          if (serverOnboarding == true) {
            _user!['onboarding_completed'] = true;
            await prefs.setBool(_onboardingKey, true);
          } else {
            _user!['onboarding_completed'] = prefs.getBool(_onboardingKey);
          }
          _subscription = meData['subscription'] is Map ? Map<String, dynamic>.from(meData['subscription']) : null;
        } catch (_) {
          _user!['onboarding_completed'] = prefs.getBool(_onboardingKey);
        }
      }
      _isLoading = false; notifyListeners();
      if (_subscription == null) refreshSubscription();
      // Fetch signed subscription token for anti-tamper verification
      SubscriptionTokenService().fetchToken();
      return true;
    } on DioException catch (e) { _error = _getDioError(e); _isLoading = false; notifyListeners(); return false; }
    catch (e) { _error = 'حدث خطأ غير متوقع: $e'; _isLoading = false; notifyListeners(); return false; }
  }

  Future<void> refreshSubscription() async {
    if (!isAuthenticated) return;
    try {
      final meResp = await _api.dio.get('/auth/me',
        options: Options(receiveTimeout: const Duration(seconds: 10), sendTimeout: const Duration(seconds: 10)),
      );
      final me = meResp.data is Map ? meResp.data as Map<String, dynamic> : <String, dynamic>{};
      _subscription = me['subscription'] is Map ? Map<String, dynamic>.from(me['subscription']) : null;
      
      // Cache subscription status
      if (_subscription != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('subscription_cache', jsonEncode(_subscription));
        // Also fetch signed subscription token
        SubscriptionTokenService().fetchToken();
      }
      
      notifyListeners();
    } on DioException catch (_) {
    } catch (_) {}
  }

  String _getDioError(DioException e) {
    final s = e.response?.statusCode; final d = e.response?.data;
    if (e.type == DioExceptionType.connectionError) return 'أنت غير متصل بالإنترنت';
    if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) return 'تعذر الاتصال. تأكد من الإنترنت';
    if (s == 401) return 'بيانات الدخول غير صحيحة';
    if (d is Map && d['detail'] != null) return d['detail'].toString();
    if (s != null) return 'خطأ $s';
    return e.message ?? 'حدث خطأ غير معروف';
  }

  Future<void> logout() async {
    _token = null; _user = null; _subscription = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove('subscription_cache');
      await prefs.remove('refresh_token');
      await SubscriptionTokenService().clearAll();
    } catch (_) {}
    notifyListeners();
  }
}
