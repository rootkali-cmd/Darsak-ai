import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../core/analytics_service.dart';
import '../core/structured_logger.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  UserModel? _user;
  bool _isLoading = false;
  bool _initialLoadComplete = false;
  String? _error;
  bool _onboardingCompleted = false;
  List<String> _subjects = [];
  List<String> _levels = [];

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  bool get initialLoadComplete => _initialLoadComplete;
  bool get onboardingCompleted => _onboardingCompleted;
  List<String> get subjects => _subjects;
  List<String> get levels => _levels;
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = await _api.login(email, password);
      final userData = await _api.getMe();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', tokens['access_token']);
      await prefs.setString('refresh_token', tokens['refresh_token']);

      _user = UserModel.fromJson(userData);
      _onboardingCompleted = userData['onboarding_completed'] == true;
      _subjects = (userData['subjects'] as List?)?.map((e) => e.toString()).toList() ?? [];
      _levels = (userData['levels'] as List?)?.map((e) => e.toString()).toList() ?? [];
      await _cacheUser(_user!, onboardingCompleted: _onboardingCompleted, subjects: _subjects, levels: _levels);
      _isLoading = false;
      AnalyticsService.instance.loginSuccess();
      StructuredLogger.instance.info('login_success', data: { 'email': email });
      notifyListeners();
      return true;
    } catch (e) {
      // Clear partial tokens if getMe failed
      (await SharedPreferences.getInstance()).remove('access_token');
      (await SharedPreferences.getInstance()).remove('refresh_token');
      _error = e is DioException && e.response?.statusCode == 401
          ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
          : 'فشل تسجيل الدخول';
      AnalyticsService.instance.loginFailed(reason: _error);
      StructuredLogger.instance.warning('login_failed', data: { 'email': email, 'error': _error });
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      // Try cache anyway — maybe user was logged in before but token expired
      await _loadCachedUser();
      _initialLoadComplete = true;
      return;
    }

    // Load cached user immediately (instant, no internet needed)
    await _loadCachedUser();
    _initialLoadComplete = true;

    // Then refresh from server in background (silent update)
    try {
      final userData = await _api.getMe();
      _user = UserModel.fromJson(userData);
      _onboardingCompleted = userData['onboarding_completed'] == true;
      _subjects = (userData['subjects'] as List?)?.cast<String>() ?? [];
      _levels = (userData['levels'] as List?)?.cast<String>() ?? [];
      await _cacheUser(_user!, onboardingCompleted: _onboardingCompleted, subjects: _subjects, levels: _levels);
      notifyListeners();
    } catch (_) {
      // Server offline — cached data already loaded above, keep it
    }
  }

  Future<void> saveOnboarding({required String fullName, required List<String> subjects, required List<String> levels}) async {
    await _api.saveOnboarding(fullName: fullName, subjects: subjects, levels: levels);
    _onboardingCompleted = true;
    _subjects = subjects;
    _levels = levels;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    await prefs.setStringList('onboarding_subjects', subjects);
    await prefs.setStringList('onboarding_levels', levels);
    if (_user != null) {
      await _cacheUser(_user!, onboardingCompleted: true, subjects: subjects, levels: levels);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    _onboardingCompleted = false;
    _subjects = [];
    _levels = [];
    _initialLoadComplete = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('cached_user_id');
    await prefs.remove('cached_user_name');
    await prefs.remove('cached_user_email');
    await prefs.remove('cached_user_role');
    await prefs.remove('cached_user_code');
    await prefs.remove('cached_user_is_active');
    await prefs.remove('cached_user_created_at');
    await prefs.remove('subscription_data');
    notifyListeners();
  }

  Future<void> _cacheUser(UserModel user, {bool onboardingCompleted = false, List<String> subjects = const [], List<String> levels = const []}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_id', user.id);
    await prefs.setString('cached_user_name', user.fullName);
    await prefs.setString('cached_user_email', user.email);
    await prefs.setString('cached_user_role', user.role);
    await prefs.setString('cached_user_code', user.teacherCode ?? '');
    await prefs.setBool('cached_user_is_active', user.isActive);
    await prefs.setString('cached_user_created_at', user.createdAt.toIso8601String());
    await prefs.setBool('cached_onboarding_completed', onboardingCompleted);
    await prefs.setStringList('cached_onboarding_subjects', subjects);
    await prefs.setStringList('cached_onboarding_levels', levels);
  }

  Future<void> _loadCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedId = prefs.getString('cached_user_id');
    final cachedName = prefs.getString('cached_user_name');
    final cachedEmail = prefs.getString('cached_user_email');
    if (cachedId != null && cachedName != null && cachedEmail != null) {
      _user = UserModel(
        id: cachedId,
        fullName: cachedName,
        email: cachedEmail,
        role: prefs.getString('cached_user_role') ?? 'teacher',
        teacherCode: prefs.getString('cached_user_code'),
        isActive: prefs.getBool('cached_user_is_active') ?? true,
        createdAt: DateTime.tryParse(prefs.getString('cached_user_created_at') ?? '') ?? DateTime.now(),
      );
      _onboardingCompleted = prefs.getBool('cached_onboarding_completed') ?? false;
      _subjects = prefs.getStringList('cached_onboarding_subjects') ?? [];
      _levels = prefs.getStringList('cached_onboarding_levels') ?? [];
      notifyListeners();
    }
  }
}
