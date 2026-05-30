import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/error_utils.dart';

class StudentsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get students => _filteredStudents.isEmpty && _searchQuery.isEmpty ? _students : _filteredStudents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String _searchQuery = '';

  Future<void> loadStudents() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _students = await _api.getStudents(search: _searchQuery.isNotEmpty ? _searchQuery : null);
      _filteredStudents = _students;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تحميل الطلاب: ${getFriendlyErrorMessage(e)}';
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    if (query.isEmpty) {
      _filteredStudents = _students;
    } else {
      final lower = query.toLowerCase();
      _filteredStudents = _students.where((s) {
        final name = (s['full_name'] ?? s['name'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        return name.contains(lower) || phone.contains(lower);
      }).toList();
    }
    notifyListeners();
  }

  Future<bool> createStudent(Map<String, dynamic> data) async {
    try {
      await _api.createStudent(data);
      await loadStudents();
      return true;
    } catch (e) {
      _error = 'فشل إضافة الطالب: ${getFriendlyErrorMessage(e)}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStudent(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateStudent(id, data);
      await loadStudents();
      return true;
    } catch (e) {
      _error = 'فشل تحديث الطالب: ${getFriendlyErrorMessage(e)}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStudent(int id) async {
    try {
      await _api.deleteStudent(id);
      _students.removeWhere((s) => s['id'] == id);
      search(_searchQuery);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف الطالب: ${getFriendlyErrorMessage(e)}';
      notifyListeners();
      return false;
    }
  }
}
