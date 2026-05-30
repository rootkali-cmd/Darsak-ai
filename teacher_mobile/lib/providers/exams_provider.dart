import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ExamsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _exams = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get exams => _exams;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadExams() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _exams = await _api.getExams();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تحميل الاختبارات';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createExam(Map<String, dynamic> data) async {
    try {
      await _api.createExam(data);
      await loadExams();
      return true;
    } catch (e) {
      _error = 'فشل إضافة الاختبار';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExam(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateExam(id, data);
      await loadExams();
      return true;
    } catch (e) {
      _error = 'فشل تحديث الاختبار';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteExam(int id) async {
    try {
      await _api.deleteExam(id);
      _exams.removeWhere((e) => e['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف الاختبار';
      notifyListeners();
      return false;
    }
  }
}
