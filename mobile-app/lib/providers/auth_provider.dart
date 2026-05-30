import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  AuthStatus _status = AuthStatus.uninitialized;
  StudentModel? _student;
  String? _error;
  String? _teacherCode;
  bool _isSubscriptionActive = false;
  Map<String, dynamic>? _subscriptionData;

  AuthStatus get status => _status;
  StudentModel? get student => _student;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get teacherCode => _teacherCode;
  bool get isSubscriptionActive => _isSubscriptionActive;
  bool get isOnline => true;
  Map<String, dynamic>? get subscriptionData => _subscriptionData;

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
    // Don't change status to loading — AuthGate would rebuild and break the flow.
    // LoginScreen manages its own loading indicator locally.

    try {
      final response = await _api.login(code, pin, teacherCode: teacherCode);
      final token = response['access_token'] as String;

      await _storage.write(key: AppConstants.storageKeyToken, value: token);
      await _storage.write(key: AppConstants.storageKeyCode, value: code);
      if (teacherCode != null) {
        await _storage.write(
            key: AppConstants.storageKeyTeacherCode, value: teacherCode);
        _teacherCode = teacherCode;
      }

      // Fetch full profile
      final profile = await _api.getProfile();
      _student = StudentModel.fromJson(profile);
      LocalDB.saveProfile(profile);

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
      _error = 'خطأ في كود الطالب أو PIN';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
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
