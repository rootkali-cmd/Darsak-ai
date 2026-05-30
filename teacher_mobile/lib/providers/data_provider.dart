import 'package:flutter/foundation.dart';
import '../core/api/api_service.dart';
import '../core/database/database_service.dart';
import '../core/sync/sync_service.dart';
import '../core/models/student.dart';
import '../core/models/group.dart';

final class DataProvider extends ChangeNotifier {
  final ApiService _api;
  final SyncService _sync;
  final DatabaseService _db;
  List<StudentModel> _students = [];
  List<GroupModel> _groups = [];
  bool _isLoading = false;
  bool _pendingNotify = false;
  DateTime _lastServerFetch = DateTime(2000);

  List<StudentModel> get students => _students;
  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isOffline => !_sync.isOnline;
  ApiService get api => _api;
  int get pendingChangesCount => _sync.pendingCount;

  DataProvider({
    required ApiService api,
    required SyncService sync,
    required DatabaseService db,
  })  : _api = api,
        _sync = sync,
        _db = db {
    _sync.addListener(_onSyncChange);
  }

  @override
  void dispose() {
    _sync.removeListener(_onSyncChange);
    super.dispose();
  }

  void _onSyncChange(String status, String type) {
    if (type == 'connected' || type == 'synced') {
      if (DateTime.now().difference(_lastServerFetch) > const Duration(seconds: 15)) {
        final prevStudents = _students.length;
        final prevGroups = _groups.length;
        _loadFromLocal();
        if (_students.length != prevStudents || _groups.length != prevGroups) {
          _scheduleNotify();
        }
      }
    }
  }

  void _scheduleNotify() {
    if (!_pendingNotify) {
      _pendingNotify = true;
      Future.microtask(() {
        _pendingNotify = false;
        notifyListeners();
      });
    }
  }

  Future<void> loadData() async {
    _loadFromLocal();
    _isLoading = _students.isEmpty && _groups.isEmpty;
    notifyListeners();

    if (DateTime.now().difference(_lastServerFetch) > const Duration(seconds: 30)) {
      _backgroundSync();
    }
  }

  void _backgroundSync() {
    final prevStudentCount = _students.length;
    final prevGroupCount = _groups.length;

    Future.any([
      _syncFromApi(),
      Future.delayed(const Duration(seconds: 8)),
    ]).then((_) {
      _loadFromLocal();
      final changed = _students.length != prevStudentCount || _groups.length != prevGroupCount;
      if (changed) {
        notifyListeners();
      }
    }).catchError((e) {});
  }

  void _loadFromLocal() {
    _students = _db.getAllStudents();
    _groups = _db.getAllGroups();
  }

  Future<void> _syncFromApi() async {
    try {
      final pendingIds = <String>{};
      final pendingDeleteIds = <String>{};
      final queueItems = _db.getUnsyncedItems();
      for (final item in queueItems) {
        final data = item['data'] as Map?;
        if (data != null) {
          final id = data['id']?.toString();
          final code = data['code']?.toString();
          if (id != null && id.isNotEmpty) pendingIds.add(id);
          if (code != null && code.isNotEmpty) pendingIds.add(code);
          if (item['type'] == 'delete_student') {
            if (id != null && id.isNotEmpty) pendingDeleteIds.add(id);
            if (code != null && code.isNotEmpty) pendingDeleteIds.add(code);
          }
        }
      }

      final studentsData = await _api.getStudents();
      final groupsData = await _api.getGroups();

      if (studentsData.isNotEmpty) {
        final apiStudents =
            studentsData.map((s) => StudentModel.fromJson(s as Map<String, dynamic>)).toList();
        for (final s in apiStudents) {
          if (!pendingIds.contains(s.id) && !pendingIds.contains(s.code)) {
            _db.saveStudent(s);
          }
        }
        _students = apiStudents
            .where((s) => !pendingDeleteIds.contains(s.id) && !pendingDeleteIds.contains(s.code))
            .toList();
      }

      if (groupsData.isNotEmpty) {
        final apiGroups =
            groupsData.map((g) => GroupModel.fromJson(g as Map<String, dynamic>)).toList();
        for (final g in apiGroups) {
          if (!pendingIds.contains(g.id)) {
            _db.saveGroup(g);
          }
        }
        _groups = apiGroups;
      }

      _lastServerFetch = DateTime.now();
    } catch (e) {}
  }

  void addStudentLocally(StudentModel student) {
    final idx = _students.indexWhere((s) => s.code == student.code);
    if (idx != -1) {
      _students[idx] = student;
    } else {
      _students.add(student);
    }
    _db.saveStudent(student);
    notifyListeners();
    _sync.immediatePush('student', student.code, student.toJson());
  }

  void addGroupLocally(GroupModel group) {
    final idx = _groups.indexWhere((g) => g.id == group.id);
    if (idx != -1) {
      _groups[idx] = group;
    } else {
      _groups.add(group);
    }
    _db.saveGroup(group);
    _sync.immediatePush('group', group.id, group.toJson());
    notifyListeners();
  }

  void updateStudentPinStatus(String studentId, bool hasPin) {
    final idx = _students.indexWhere((s) => s.id == studentId);
    if (idx == -1) return;
    _students[idx] = _students[idx].copyWith(hasPin: hasPin);
    _db.saveStudent(_students[idx]);
    notifyListeners();
  }

  Future<bool> resetStudentPin(String studentId, String pin) async {
    updateStudentPinStatus(studentId, true);
    try {
      await _api.resetStudentPin(studentId, pin).timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      _sync.immediatePush('pin', studentId, {'student_id': studentId, 'pin': pin});
      return false;
    }
  }

  void removeStudent(String studentId, String studentCode) {
    _students.removeWhere((s) => s.id == studentId);
    _db.deleteStudent(studentCode);
    if (studentId != studentCode) _db.deleteStudentById(studentId);
    _sync.queueOnly('delete_student', studentId, {'id': studentId, 'code': studentCode});
    notifyListeners();
  }

  void removeGroup(String groupId) {
    _groups.removeWhere((g) => g.id == groupId);
    _db.deleteGroup(groupId);
    _sync.immediatePush('delete_group', groupId, {'id': groupId});
    notifyListeners();
  }

  void updateStudentId(String oldCode, String newId) {
    final idx = _students.indexWhere((s) => s.code == oldCode);
    if (idx == -1) return;
    _students[idx] = _students[idx].copyWith(id: newId);
    _db.saveStudent(_students[idx]);
    notifyListeners();
  }

  List<StudentModel> filterStudents({String? search, String? groupId}) {
    return _db.searchStudents(search: search, groupId: groupId);
  }

  List<StudentModel> get studentsInMemory => _students;
  List<GroupModel> get groupsInMemory => _groups;
}
