import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/local_db.dart';
import '../core/subscription_service.dart';
import '../models/student.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading, subscriptionExpired }

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SubscriptionService _subscriptionService = SubscriptionService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Connectivity _connectivity = Connectivity();
  AuthStatus _status = AuthStatus.uninitialized;
  StudentModel? _student;
  String? _error;
  String? _teacherCode;
  bool _isSubscriptionActive = false;
  Map<String, dynamic>? _subscriptionData;
  bool _isOnline = true;

  AuthStatus get status => _status;
  StudentModel? get student => _student;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get teacherCode => _teacherCode;
  bool get isSubscriptionActive => _isSubscriptionActive;
  bool get isOnline => _isOnline;
  Map<String, dynamic>? get subscriptionData => _subscriptionData;

  AuthProvider() {
    _initConnectivity();
  }

  void _initConnectivity() {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      notifyListeners();
    });
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((r) => r != ConnectivityResult.none);
    notifyListeners();
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

    // Verify token is still valid before logging in
    try {
      final data = await _api.getProfile();
      _student = StudentModel.fromJson(data);
      LocalDB.saveProfile(data);
    } catch (_) {
      // Token expired or invalid — clear and go to login
      await _storage.delete(key: AppConstants.storageKeyToken);
      await _storage.delete(key: AppConstants.storageKeyTeacherCode);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Check subscription from cache (will be refreshed later)
    final subActive = await _subscriptionService.isSubscriptionActive();
    _isSubscriptionActive = subActive;
    _subscriptionData = await _subscriptionService.getCachedSubscription();

    if (!subActive) {
      // Still allow login but mark subscription expired — overlay will show
    }

    _status = AuthStatus.authenticated;
    notifyListeners();

    // Refresh subscription in background
    try {
      final subData = await _subscriptionService.getMySubscription();
      _subscriptionData = subData;
      _isSubscriptionActive = await _subscriptionService.isSubscriptionActive();
      if (!_isSubscriptionActive) {
        _status = AuthStatus.subscriptionExpired;
      }
      notifyListeners();
    } catch (_) {}
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

      await _storage.write(key: AppConstants.storageKeyToken, value: token);
      await _storage.write(key: AppConstants.storageKeyCode, value: code);
      if (teacherCode != null) {
        await _storage.write(
            key: AppConstants.storageKeyTeacherCode, value: teacherCode);
        _teacherCode = teacherCode;
      }

      // Fetch full profile — if this fails, still treat login as successful
      // (the profile can be loaded later from tryAutoLogin)
      try {
        final profile = await _api.getProfile();
        _student = StudentModel.fromJson(profile);
        LocalDB.saveProfile(profile);
      } catch (_) {
        // Profile fetch failed after login — build minimal student from login data
        _student = StudentModel(
          id: response['student_id']?.toString() ?? '',
          code: response['student_code']?.toString() ?? code,
          fullName: '',
          createdAt: DateTime.now(),
        );
      }

      // Check subscription
      try {
        final subData = await _subscriptionService.getMySubscription();
        _subscriptionData = subData;
        _isSubscriptionActive = await _subscriptionService.isSubscriptionActive();
      } catch (_) {
        _isSubscriptionActive = false;
        _subscriptionData = null;
      }

      if (!_isSubscriptionActive) {
        _status = AuthStatus.subscriptionExpired;
        notifyListeners();
        return true;
      }

      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      String message = _mapLoginError(e);
      _error = message;
      // Clear any leftover token on failure
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

      // Extract the detail/message string from the response
      String raw = '';
      if (data is Map<String, dynamic>) {
        raw = data['detail'] as String? ??
            data['message'] as String? ??
            data['error'] as String? ??
            '';
      } else if (data is String && data.isNotEmpty) {
        raw = data;
      }

      // Rate limiting (429)
      if (statusCode == 429) {
        // Backend returns specific Arabic messages for rate limiting
        if (raw.isNotEmpty) return raw;
        return 'تم حظر حسابك مؤقتاً بسبب محاولات كثيرة. حاول مرة أخرى لاحقاً.';
      }

      // Suspended / banned (403)
      if (statusCode == 403 || raw.contains('معلّق') || raw.contains('محظور') || raw.toLowerCase().contains('suspend')) {
        return 'تم تعليق الحساب';
      }

      // Specific backend Arabic messages for 401 errors — match exactly what the backend sends
      if (raw == 'الكود غير صحيح') return 'كود الطالب غير صحيح';
      if (raw == 'الرمز السري غير صحيح') return 'كلمة المرور غير صحيحة';
      if (raw == 'الرمز السري غير مُعيّن') return 'لم يتم تعيين رمز سري لهذا الحساب';
      if (raw == 'الطالب غير مسجل لدى هذا المعلم') return 'الطالب غير مسجل لدى هذا المعلم';

      // Fallback for any other 401
      if (statusCode == 401) {
        if (raw.isNotEmpty) return raw;
        return 'الكود أو كلمة المرور غير صحيحة';
      }

      // Any other error with a message — show the backend message
      if (raw.isNotEmpty) return raw;
    }

    // Non-Dio errors (timeout, no internet, etc.)
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

  Future<void> refreshSubscription() async {
    try {
      final subData = await _subscriptionService.getMySubscription();
      _subscriptionData = subData;
      _isSubscriptionActive = await _subscriptionService.isSubscriptionActive();
      if (_isSubscriptionActive) {
        _status = AuthStatus.authenticated;
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    await _subscriptionService.clearCache();
    LocalDB.clearAll();
    _student = null;
    _teacherCode = null;
    _subscriptionData = null;
    _isSubscriptionActive = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
