import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_service.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  Future<bool> get isOnboardingCompleted async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }
  String? get error => _error;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final tokens = await _api.login(email, password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', tokens['access_token']);
      await prefs.setString('refresh_token', tokens['refresh_token']);

      final userData = await _api.getMe();
      _user = UserModel.fromJson(userData);
      // Save user locally for offline access
      await _cacheUser(_user!);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().contains('401')
          ? 'البريد الإلكتروني أو كلمة المرور غير صحيحة'
          : 'فشل تسجيل الدخول';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) return;

    try {
      final userData = await _api.getMe();
      _user = UserModel.fromJson(userData);
      // Update cached user data
      await _cacheUser(_user!);
      notifyListeners();
    } catch (_) {
      // If offline, load cached user data
      await _loadCachedUser();
    }
  }

  Future<void> logout() async {
    _user = null;
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
    notifyListeners();
  }

  Future<void> _cacheUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_id', user.id);
    await prefs.setString('cached_user_name', user.fullName);
    await prefs.setString('cached_user_email', user.email);
    await prefs.setString('cached_user_role', user.role);
    await prefs.setString('cached_user_code', user.teacherCode ?? '');
    await prefs.setBool('cached_user_is_active', user.isActive);
    await prefs.setString('cached_user_created_at', user.createdAt.toIso8601String());
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
      notifyListeners();
    }
  }
}
