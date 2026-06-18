import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/local_db.dart';
import '../core/account_manager.dart';
import '../models/student.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Connectivity _connectivity = Connectivity();
  final AccountManager _accountManager = AccountManager();
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
  AccountManager get accountManager => _accountManager;
  bool get isSubscriptionActive {
    if (_subscriptionData == null) return false;
    final isActive = _subscriptionData!['is_active'] ?? false;
    if (isActive != true) return false;
    final expiresAt = _subscriptionData!['expires_at'] as String?;
    if (expiresAt != null) {
      final expiry = DateTime.tryParse(expiresAt);
      if (expiry != null && expiry.isBefore(DateTime.now())) return false;
    }
    return true;
  }

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
    } catch (_) {}
  }

  Future<void> tryAutoLogin() async {
    await _accountManager.load();

    final token = await _storage.read(key: AppConstants.storageKeyToken);
    if (token == null && _accountManager.accounts.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final active = _accountManager.activeAccount;
    if (active != null) {
      await _storage.write(key: AppConstants.storageKeyToken, value: active.accessToken);
      await _storage.write(key: AppConstants.storageKeyRefreshToken, value: active.refreshToken);
      _teacherCode = active.teacherCode;
    }

    final cached = LocalDB.getProfile();
    if (cached != null) {
      _student = StudentModel.fromJson(cached);
    }

    _status = AuthStatus.authenticated;
    notifyListeners();

    refreshSubscription();

    try {
      final data = await _api.getProfile();
      _student = StudentModel.fromJson(data);
      LocalDB.saveProfile(data);
    } catch (e) {
      if (e is DioException && e.response != null) {
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
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

  Future<bool> login(String code, String pin, {String? teacherCode}) async {
    _error = null;

    try {
      await _storage.delete(key: AppConstants.storageKeyToken);
      LocalDB.clearAll();

      final response = await _api.login(code, pin, teacherCode: teacherCode);
      final token = response['access_token'] as String;
      final refreshToken = response['refresh_token'] as String?;
      final studentId = response['student_id']?.toString() ?? '';

      await _storage.write(key: AppConstants.storageKeyToken, value: token);
      if (refreshToken != null) {
        await _storage.write(key: AppConstants.storageKeyRefreshToken, value: refreshToken);
      }
      await _storage.write(key: AppConstants.storageKeyCode, value: code);
      if (teacherCode != null) {
        await _storage.write(key: AppConstants.storageKeyTeacherCode, value: teacherCode);
        _teacherCode = teacherCode;
      }

      String studentName = '';
      try {
        final profile = await _api.getProfile();
        _student = StudentModel.fromJson(profile);
        LocalDB.saveProfile(profile);
        studentName = _student?.fullName ?? '';
      } catch (_) {
        _student = StudentModel(
          id: studentId,
          code: response['student_code']?.toString() ?? code,
          fullName: '',
          createdAt: DateTime.now(),
        );
      }

      final account = StudentAccount(
        studentId: studentId,
        studentCode: response['student_code']?.toString() ?? code,
        studentName: studentName,
        accessToken: token,
        refreshToken: refreshToken ?? '',
        teacherId: _student?.teacherId ?? '',
        teacherCode: teacherCode,
        teacherName: null,
      );
      await _accountManager.addAccount(account);

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

  Future<bool> addAccount(String code, String pin) async {
    try {
      final response = await Dio().post(
        '${AppConstants.apiBaseUrl}/students/verify-account',
        data: {'code': code, 'pin': pin},
      );
      final data = response.data as Map<String, dynamic>;

      final account = StudentAccount(
        studentId: data['student_id']?.toString() ?? '',
        studentCode: data['student_code']?.toString() ?? code,
        studentName: data['student_name'] ?? '',
        accessToken: data['access_token'] ?? '',
        refreshToken: data['refresh_token'] ?? '',
        teacherId: data['teacher_id']?.toString() ?? '',
        teacherCode: null,
        teacherName: null,
      );

      final added = await _accountManager.addAccount(account);
      if (!added) {
        _error = 'الحساب موجود بالفعل أو تم الوصول للحد الأقصى';
        notifyListeners();
        return false;
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (e is DioException && e.response != null) {
        final data = e.response?.data;
        final detail = data is Map ? data['detail'] : null;
        _error = detail ?? 'فشل إضافة الحساب';
      } else {
        _error = 'حدث خطأ أثناء إضافة الحساب';
      }
      notifyListeners();
      return false;
    }
  }

  Future<void> switchAccount(int index) async {
    await _accountManager.switchTo(index);
    final account = _accountManager.activeAccount;
    if (account == null) return;

    await _storage.write(key: AppConstants.storageKeyToken, value: account.accessToken);
    await _storage.write(key: AppConstants.storageKeyRefreshToken, value: account.refreshToken);
    _teacherCode = account.teacherCode;

    LocalDB.clearAll();
    _student = null;
    _subscriptionData = null;

    try {
      final profile = await _api.getProfile();
      _student = StudentModel.fromJson(profile);
      LocalDB.saveProfile(profile);
    } catch (_) {}

    notifyListeners();
    refreshSubscription();
  }

  Future<void> removeAccount(int index) async {
    final wasActive = index == _accountManager.activeIndex;
    await _accountManager.removeAccount(index);

    if (wasActive && _accountManager.accounts.isNotEmpty) {
      await switchAccount(0);
    } else if (_accountManager.accounts.isEmpty) {
      await logout();
    } else {
      notifyListeners();
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
