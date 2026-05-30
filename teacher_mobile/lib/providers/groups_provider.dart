import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class GroupsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<dynamic> _groups = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get groups => _groups;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGroups() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _groups = await _api.getGroups();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'فشل تحميل المجموعات';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGroup(Map<String, dynamic> data) async {
    try {
      await _api.createGroup(data);
      await loadGroups();
      return true;
    } catch (e) {
      _error = 'فشل إضافة المجموعة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateGroup(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateGroup(id, data);
      await loadGroups();
      return true;
    } catch (e) {
      _error = 'فشل تحديث المجموعة';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(int id) async {
    try {
      await _api.deleteGroup(id);
      _groups.removeWhere((g) => g['id'] == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'فشل حذف المجموعة';
      notifyListeners();
      return false;
    }
  }
}
