import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class AttendanceProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _attendance = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get attendance => _attendance;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String get today => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Future<void> loadAttendance({String? date}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _attendance = await _api.getAttendance(date: date ?? today);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تحميل سجل الحضور';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> markAttendance(int studentId, {String? status}) async {
    try {
      final result = await _api.markAttendance({
        'student_id': studentId,
        'date': today,
        'status': status ?? 'present',
      });
      await loadAttendance();
      return result;
    } catch (e) {
      _error = 'فشل تسجيل الحضور';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> markAttendanceByBarcode(String barcode) async {
    try {
      final result = await _api.markAttendanceByBarcode(barcode);
      await loadAttendance();
      return result;
    } catch (e) {
      _error = 'فشل تسجيل الحضور بالباركود';
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStats() async {
    try {
      return await _api.getAttendanceStats();
    } catch (e) {
      return null;
    }
  }

  Future<List<dynamic>> getStudentAttendance(int studentId) async {
    try {
      return await _api.getStudentAttendance(studentId);
    } catch (e) {
      return [];
    }
  }
}
