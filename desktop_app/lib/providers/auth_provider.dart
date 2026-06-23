import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api/api_client.dart';
import '../core/api/api_service.dart';
import '../core/utils/constants.dart';
import '../core/utils/logger.dart';
import '../core/services/subscription_service.dart';
import '../core/models/user.dart';

final class AuthProvider extends ChangeNotifier {
  final ApiClient client;
  late final ApiService _api;
  final FlutterSecureStorage _secureStorage;
  UserModel? _user;
  bool _isLoading = false;
  bool _initialLoadComplete = false;
  String? _error;
  bool _onboardingCompleted = false;
  List<String> _subjects = [];
  List<String> _levels = [];
  Map<String, dynamic>? _subscriptionData;
  bool _subscriptionLoaded = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get initialLoadComplete => _initialLoadComplete;
  bool get onboardingCompleted => _onboardingCompleted;
  List<String> get subjects => _subjects;
  List<String> get levels => _levels;
  String? get error => _error;
  Map<String, dynamic>? get subscriptionData => _subscriptionData;
  bool get subscriptionLoaded => _subscriptionLoaded;

  bool get hasSubscription {
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

  AuthProvider(this.client)
      : _api = ApiService(client),
        _secureStorage = const FlutterSecureStorage();

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = await _api.login(email, password);
      await _saveTokens(
        tokens['access_token']?.toString() ?? '',
        tokens['refresh_token']?.toString() ?? '',
      );
      final userData = await _api.getMe();
      _user = UserModel.fromJson(userData);
      _onboardingCompleted = userData['onboarding_completed'] == true;
      _subjects = (userData['subjects'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _levels = (userData['levels'] as List?)?.map((e) => e.toString()).toList() ?? [];
      await _cacheUser(_user!);
      _isLoading = false;
      AppLogger.instance.info('login_success', data: {'email': email});
      notifyListeners();
      refreshSubscription();
      return true;
    } catch (e) {
      await _clearTokens();
      _error = e is DioException && e.response?.statusCode == 401
          ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
          : 'فشل تسجيل الدخول';
      AppLogger.instance.warning('login_failed', data: {'email': email, 'error': _error});
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUser() async {
    String? token;
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(PrefKeys.accessToken);
    } catch (_) {}
    if (token == null || token.isEmpty) {
      try {
        token = await _secureStorage.read(key: PrefKeys.accessToken);
      } catch (_) {}
    }
    if (token == null || token.isEmpty) {
      await _loadCachedUser();
      _initialLoadComplete = true;
      notifyListeners();
      return;
    }
    await _loadCachedUser();
    _initialLoadComplete = true;
    notifyListeners();
    try {
      final userData = await _api.getMe();
      _user = UserModel.fromJson(userData);
      _onboardingCompleted = userData['onboarding_completed'] == true;
      _subjects = (userData['subjects'] as List?)?.cast<String>() ?? [];
      _levels = (userData['levels'] as List?)?.cast<String>() ?? [];
      await _cacheUser(_user!);
      notifyListeners();
      refreshSubscription();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        await logout();
      }
    }
  }

  Future<void> saveOnboarding({
    required String fullName,
    required List<String> subjects,
    required List<String> levels,
  }) async {
    await _api.saveOnboarding(fullName: fullName, subjects: subjects, levels: levels);
    _onboardingCompleted = true;
    _subjects = subjects;
    _levels = levels;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefKeys.onboardingCompleted, true);
    await prefs.setStringList(PrefKeys.onboardingSubjects, subjects);
    await prefs.setStringList(PrefKeys.onboardingLevels, levels);
    if (_user != null) await _cacheUser(_user!);
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _onboardingCompleted = false;
    _subjects = [];
    _levels = [];
    _subscriptionData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefKeys.cachedUserId);
    await prefs.remove(PrefKeys.cachedUserName);
    await prefs.remove(PrefKeys.cachedUserEmail);
    await prefs.remove(PrefKeys.cachedUserRole);
    await prefs.remove(PrefKeys.cachedUserCode);
    await prefs.remove(PrefKeys.cachedUserIsActive);
    await prefs.remove(PrefKeys.cachedUserCreatedAt);
    await prefs.remove(PrefKeys.subscriptionData);
    await _clearTokens();
    notifyListeners();
  }

  Future<void> refreshSubscription() async {
    try {
      final subService = SubscriptionService(client);
      // Load from cache first for instant UI
      if (_subscriptionData == null) {
        final cached = await subService.getCachedSubscription();
        if (cached != null) {
          _subscriptionData = cached;
          _subscriptionLoaded = true;
          notifyListeners();
        }
      }
      // Then fetch from API
      final data = await subService.getMySubscription();
      _subscriptionData = data;
      _subscriptionLoaded = true;
      await subService.cacheSubscription(data);
      notifyListeners();
    } catch (_) {
      _subscriptionLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.accessToken, accessToken);
      if (refreshToken.isNotEmpty) {
        await prefs.setString(PrefKeys.refreshToken, refreshToken);
      }
    } catch (_) {}
    try {
      await _secureStorage.write(key: PrefKeys.accessToken, value: accessToken);
      if (refreshToken.isNotEmpty) {
        await _secureStorage.write(key: PrefKeys.refreshToken, value: refreshToken);
      }
    } catch (_) {}
  }

  Future<void> _clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PrefKeys.accessToken);
      await prefs.remove(PrefKeys.refreshToken);
    } catch (_) {}
    try {
      await _secureStorage.delete(key: PrefKeys.accessToken);
      await _secureStorage.delete(key: PrefKeys.refreshToken);
    } catch (_) {}
  }

  Future<void> _cacheUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefKeys.cachedUserId, user.id);
    await prefs.setString(PrefKeys.cachedUserName, user.fullName);
    await prefs.setString(PrefKeys.cachedUserEmail, user.email);
    await prefs.setString(PrefKeys.cachedUserRole, user.role);
    await prefs.setString(PrefKeys.cachedUserCode, user.teacherCode ?? '');
    await prefs.setBool(PrefKeys.cachedUserIsActive, user.isActive);
    await prefs.setString(PrefKeys.cachedUserCreatedAt, user.createdAt.toIso8601String());
  }

  Future<void> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString(PrefKeys.cachedUserId);
    final cachedName = prefs.getString(PrefKeys.cachedUserName);
    final cachedEmail = prefs.getString(PrefKeys.cachedUserEmail);
    if (cachedId != null && cachedName != null && cachedEmail != null) {
      _user = UserModel(
        id: cachedId,
        fullName: cachedName,
        email: cachedEmail,
        role: prefs.getString(PrefKeys.cachedUserRole) ?? 'teacher',
        teacherCode: prefs.getString(PrefKeys.cachedUserCode),
        isActive: prefs.getBool(PrefKeys.cachedUserIsActive) ?? true,
        createdAt: DateTime.tryParse(prefs.getString(PrefKeys.cachedUserCreatedAt) ?? '') ??
            DateTime.now(),
      );
      _onboardingCompleted = prefs.getBool(PrefKeys.onboardingCompleted) ?? false;
      _subjects = prefs.getStringList(PrefKeys.onboardingSubjects) ?? [];
      _levels = prefs.getStringList(PrefKeys.onboardingLevels) ?? [];
      notifyListeners();
    }
  }
}
