import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/local_db.dart';
import '../models/student.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Connectivity _connectivity = Connectivity();
  AuthStatus _status = AuthStatus.uninitialized;
  StudentModel? _student;
  String? _error;
  String? _teacherCode;
  bool _isOnline = true;
  Map<String, dynamic>? _subscriptionData;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  AuthStatus get status => _status;
  StudentModel? get student => _student;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get teacherCode => _teacherCode;
  bool get isOnline => _isOnline;
  Map<String, dynamic>? get subscriptionData => _subscriptionData;
  bool get isSubscriptionActive => _subscriptionData != null && (_subscriptionData!['is_active'] ?? false) == true;

  AuthProvider() {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
    _checkConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    notifyListeners();
  }

  Future<void> refreshSubscription() async {
    try {
      _subscriptionData = await _api.getMySubscription();
      notifyListeners();
    } catch (_) {
      // Silently fail — subscription state stays unchanged
    }
  }

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: AppConstants.storageKeyToken);
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _teacherCode =
        await _storage.read(key: AppConstants.storageKeyTeacherCode);

    // Load cached profile immediately so the UI has something to show
    final cached = LocalDB.getProfile();
    if (cached != null) {
      _student = StudentModel.fromJson(cached);
    }

    // Show the app — don't block on network
    _status = AuthStatus.authenticated;
    notifyListeners();

    // Load subscription data in background
    refreshSubscription();

    // Verify token and refresh data in background
    try {
      final data = await _api.getProfile();
      _student = StudentModel.fromJson(data);
      LocalDB.saveProfile(data);
    } catch (e) {
      if (e is DioException && e.response != null) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          // Try manual refresh as fallback
          final refreshToken = await _storage.read(key: AppConstants.storageKeyRefreshToken);
          bool refreshed = false;
          if (refreshToken != null) {
            try {
              final dio = Dio(BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
                headers: {'Content-Type': 'application/json'},
              ));
              final resp = await dio.post('/students/refresh', data: {
                'refresh_token': refreshToken,
              });
              final newAccess = resp.data['access_token'] as String?;
              final newRefresh = resp.data['refresh_token'] as String?;
              if (newAccess != null) {
                await _storage.write(key: AppConstants.storageKeyToken, value: newAccess);
                if (newRefresh != null) {
                  await _storage.write(key: AppConstants.storageKeyRefreshToken, value: newRefresh);
                }
                try {
                  final data2 = await _api.getProfile();
                  _student = StudentModel.fromJson(data2);
                  LocalDB.saveProfile(data2);
                  refreshed = true;
                } catch (_) {}
              }
            } catch (_) {}
          }
          if (!refreshed) {
            await _storage.delete(key: AppConstants.storageKeyToken);
            await _storage.delete(key: AppConstants.storageKeyRefreshToken);
            await _storage.delete(key: AppConstants.storageKeyTeacherCode);
            _status = AuthStatus.unauthenticated;
            notifyListeners();
            return;
          }
        }
      }
    }
  }

  Future<bool> login(String code, String pin, {String? teacherCode}) async {
    _error = null;

    try {
      // Clear stale token so the interceptor won't send it during login
      await _storage.delete(key: AppConstants.storageKeyToken);
      // Clear cached profile so old data isn't shown
      LocalDB.clearAll();

      final response = await _api.login(code, pin, teacherCode: teacherCode);
      final token = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String?;

      await _storage.write(key: AppConstants.storageKeyToken, value: token);
      if (refreshToken != null) {
        await _storage.write(key: AppConstants.storageKeyRefreshToken, value: refreshToken);
      }
      await _storage.write(key: AppConstants.storageKeyCode, value: code);
      if (teacherCode != null) {
        await _storage.write(
            key: AppConstants.storageKeyTeacherCode, value: teacherCode);
        _teacherCode = teacherCode;
      }

      // Fetch full profile — if this fails, still treat login as successful
      try {
        final profile = await _api.getProfile();
        _student = StudentModel.fromJson(profile);
        LocalDB.saveProfile(profile);
      } catch (_) {
        _student = StudentModel(
          id: response['student_id']?.toString() ?? '',
          code: response['student_code']?.toString() ?? code,
          fullName: '',
          createdAt: DateTime.now(),
        );
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      refreshSubscription();
      return true;
    } catch (e) {
      String message = _mapLoginError(e);
      _error = message;
      await _storage.delete(key: AppConstants.storageKeyToken);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  String _mapLoginError(dynamic e) {
    if (e is DioException && e.response != null) {
      final data = e.response?.data;
      final statusCode = e.response?.statusCode;

      String raw = '';
      if (data is Map<String, dynamic>) {
        raw = data['detail'] as String? ??
            data['message'] as String? ??
            data['error'] as String? ??
            '';
      } else if (data is String && data.isNotEmpty) {
        raw = data;
      }

      if (statusCode == 429) {
        if (raw.isNotEmpty) return raw;
        return 'تم حظر حسابك مؤقتاً بسبب محاولات كثيرة. حاول مرة أخرى لاحقاً.';
      }

      if (statusCode == 403 || raw.contains('معلّق') || raw.contains('محظور') || raw.toLowerCase().contains('suspend')) {
        return 'تم تعليق الحساب';
      }

      if (raw == 'الكود غير صحيح') return 'كود الطالب غير صحيح';
      if (raw == 'الرمز السري غير صحيح') return 'كلمة المرور غير صحيحة';
      if (raw == 'الرمز السري غير مُعيّن') return 'لم يتم تعيين رمز سري لهذا الحساب';
      if (raw == 'الطالب غير مسجل لدى هذا المعلم') return 'الطالب غير مسجل لدى هذا المعلم';

      if (statusCode == 401) {
        if (raw.isNotEmpty) return raw;
        return 'الكود أو كلمة المرور غير صحيحة';
      }

      if (raw.isNotEmpty) return raw;
    }

    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'انتهت مهلة الاتصال. تحقق من اتصال الإنترنت وحاول مرة أخرى.';
      }
      if (e.type == DioExceptionType.connectionError) {
        return 'لا يمكن الاتصال بالخادم. تحقق من اتصال الإنترنت.';
      }
    }

    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    LocalDB.clearAll();
    _student = null;
    _teacherCode = null;
    _subscriptionData = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
