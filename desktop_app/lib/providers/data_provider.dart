import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../core/local_db.dart';
import '../core/sync_service.dart';
import '../models/student.dart';
import '../models/group.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final SyncService _sync;
  List<StudentModel> _students = [];
  List<GroupModel> _groups = [];
  bool _isLoading = false;
  bool _isOffline = false;

  List<StudentModel> get students => _students;
  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;

  DataProvider(this._sync) {
    _sync.addListener(_onSyncChange);
  }

  void _onSyncChange(String status, String type) {
    if (type == 'synced' || type == 'connected') {
      _syncFromApi();
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    // Load from local storage first (instant)
    _loadFromLocal();
    _isLoading = false;
    notifyListeners();

    // Then try API in background
    await _syncFromApi();
  }

  void _loadFromLocal() {
    final localStudents = LocalDB.getAllData(LocalDB.studentsBox);
    _students = localStudents.map((s) => StudentModel.fromJson(s)).toList();

    final localGroups = LocalDB.getAllData(LocalDB.groupsBox);
    _groups = localGroups.map((g) => GroupModel.fromJson(g)).toList();
  }

  Future<void> _syncFromApi() async {
    try {
      final studentsData = await _api.getStudents();
      final groupsData = await _api.getGroups();

      // Only replace in-memory data if API returned non-empty data
      if (studentsData.isNotEmpty) {
        final apiStudents = studentsData.map((s) => StudentModel.fromJson(s)).toList();
        for (final s in apiStudents) {
          LocalDB.saveData(LocalDB.studentsBox, s.id, s.toJson());
        }
        _students = apiStudents;
      }

      if (groupsData.isNotEmpty) {
        final apiGroups = groupsData.map((g) => GroupModel.fromJson(g)).toList();
        for (final g in apiGroups) {
          LocalDB.saveData(LocalDB.groupsBox, g.id, g.toJson());
        }
        _groups = apiGroups;
      }

      _isOffline = false;
      notifyListeners();
    } catch (_) {
      _isOffline = true;
    }
  }

  void addStudentLocally(StudentModel student) {
    _students.add(student);
    LocalDB.saveData(LocalDB.studentsBox, student.code, student.toJson());
    LocalDB.addToSyncQueue('student', student.toJson());
    notifyListeners();
  }

  void addGroupLocally(GroupModel group) {
    _groups.add(group);
    LocalDB.saveData(LocalDB.groupsBox, group.id, group.toJson());
    LocalDB.addToSyncQueue('group', group.toJson());
    notifyListeners();
  }

  List<StudentModel> filterStudents({String? search, String? groupId}) {
    var filtered = _students;
    if (groupId != null && groupId.isNotEmpty) {
      filtered = filtered.where((s) => s.groupId == groupId).toList();
    }
    if (search != null && search.isNotEmpty) {
      filtered = filtered
          .where((s) =>
              s.fullName.toLowerCase().contains(search.toLowerCase()) ||
              s.code.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    return filtered;
  }
}
