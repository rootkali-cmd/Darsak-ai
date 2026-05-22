import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/api_service.dart';
import '../core/constants.dart';
import '../core/local_db.dart';
import '../models/student.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  AuthStatus _status = AuthStatus.uninitialized;
  StudentModel? _student;
  String? _error;
  String? _teacherCode;

  AuthStatus get status => _status;
  StudentModel? get student => _student;
  String? get error => _error;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  String? get teacherCode => _teacherCode;

  Future<void> tryAutoLogin() async {
    final token = await _storage.read(key: AppConstants.storageKeyToken);
    if (token == null) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _teacherCode =
        await _storage.read(key: AppConstants.storageKeyTeacherCode);

    // Load cached profile first
    final cached = LocalDB.getProfile();
    if (cached != null) {
      _student = StudentModel.fromJson(cached);
    }

    _status = AuthStatus.authenticated;
    notifyListeners();

    // Refresh profile in background
    try {
      final data = await _api.getProfile();
      _student = StudentModel.fromJson(data);
      LocalDB.saveProfile(data);
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

  Future<void> logout() async {
    await _storage.deleteAll();
    LocalDB.clearAll();
    _student = null;
    _teacherCode = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
