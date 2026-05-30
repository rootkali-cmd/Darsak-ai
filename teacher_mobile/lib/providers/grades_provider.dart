import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class GradesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _grades = [];
  bool _isLoading = false;
  String? _error;
  String? _subjectFilter;

  List<dynamic> get grades => _grades;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGrades({String? subject}) async {
    _isLoading = true;
    _error = null;
    _subjectFilter = subject;
    notifyListeners();

    try {
      _grades = await _api.getGrades(subject: subject);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تحميل الدرجات';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGrade(Map<String, dynamic> data) async {
    try {
      await _api.createGrade(data);
      await loadGrades(subject: _subjectFilter);
      return true;
    } catch (e) {
      _error = 'فشل إضافة الدرجة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGrade(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateGrade(id, data);
      await loadGrades(subject: _subjectFilter);
      return true;
    } catch (e) {
      _error = 'فشل تحديث الدرجة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGrade(int id) async {
    try {
      await _api.deleteGrade(id);
      _grades.removeWhere((g) => g['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف الدرجة';
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>> getStudentGrades(int studentId) async {
    try {
      return await _api.getStudentGrades(studentId);
    } catch (e) {
      return [];
    }
  }
}
