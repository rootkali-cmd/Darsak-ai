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

  final Map<String, bool> _pendingChanges = {};

  List<StudentModel> get students => _students;
  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isOffline => !_sync.isOnline;
  ApiService get api => _api;

  bool isPending(String id) => _pendingChanges[id] == true;
  int get pendingChangesCount => _pendingChanges.length;

  DataProvider(this._sync) {
    _sync.addListener(_onSyncChange);
    _sync.addOpListener(_onOpChange);
  }

  void _onSyncChange(String status, String type) {
    if (type == 'connected') { _loadFromLocal(); notifyListeners(); }
  }

  void _onOpChange(SyncOp op) {
    if (op.status == SyncOpStatus.synced || op.status == SyncOpStatus.failed) {
      _pendingChanges.remove(op.label);
      notifyListeners();
    }
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    _loadFromLocal();
    _isLoading = false;
    notifyListeners();
    await _syncFromApi();
  }

  void _loadFromLocal() {
    LocalDB.deduplicateBox(LocalDB.studentsBox, 'code');
    LocalDB.deduplicateBox(LocalDB.groupsBox, 'id');
    _students = LocalDB.getAllData(LocalDB.studentsBox).map((s) => StudentModel.fromJson(s)).toList();
    _groups = LocalDB.getAllData(LocalDB.groupsBox).map((g) => GroupModel.fromJson(g)).toList();
  }

  Future<void> _syncFromApi() async {
    try {
      final pendingIds = <String>{};
      final pendingDeleteIds = <String>{};
      for (final item in LocalDB.getUnsyncedItems()) {
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
        final apiStudents = studentsData.map((s) => StudentModel.fromJson(s)).toList();
        for (final s in apiStudents) {
          if (!pendingIds.contains(s.id) && !pendingIds.contains(s.code)) {
            LocalDB.saveData(LocalDB.studentsBox, s.code, s.toJson());
          }
        }
        _students = apiStudents
            .where((s) => !pendingDeleteIds.contains(s.id) && !pendingDeleteIds.contains(s.code))
            .toList();
      }

      if (groupsData.isNotEmpty) {
        final apiGroups = groupsData.map((g) => GroupModel.fromJson(g)).toList();
        for (final g in apiGroups) LocalDB.saveData(LocalDB.groupsBox, g.id, g.toJson());
        _groups = apiGroups;
      }

      _loadFromLocal();
      notifyListeners();
    } catch (_) {}
  }

  void addStudentLocally(StudentModel student) {
    _students.add(student);
    LocalDB.saveData(LocalDB.studentsBox, student.code, student.toJson());
    _pendingChanges[student.code] = true;
    notifyListeners();
    _sync.immediatePush('student', student.code, student.toJson());
  }

  void addGroupLocally(GroupModel group) {
    _groups.add(group);
    LocalDB.saveData(LocalDB.groupsBox, group.id, group.toJson());
    _sync.immediatePush('group', group.id, group.toJson());
    notifyListeners();
  }

  void updateStudentPinStatus(String studentId, bool hasPin) {
    final idx = _students.indexWhere((s) => s.id == studentId);
    if (idx == -1) return;
    _students[idx] = StudentModel(
      id: _students[idx].id, code: _students[idx].code,
      fullName: _students[idx].fullName, phone: _students[idx].phone,
      parentPhone: _students[idx].parentPhone, parentPhone2: _students[idx].parentPhone2,
      gradeLevel: _students[idx].gradeLevel, groupId: _students[idx].groupId,
      isPaid: _students[idx].isPaid, hasPin: hasPin,
      createdAt: _students[idx].createdAt,
    );
    LocalDB.saveData(LocalDB.studentsBox, _students[idx].code, _students[idx].toJson());
    notifyListeners();
  }

  void removeStudent(String studentId, String studentCode) {
    _students.removeWhere((s) => s.id == studentId);
    LocalDB.deleteData(LocalDB.studentsBox, studentCode);
    if (studentId != studentCode) LocalDB.deleteData(LocalDB.studentsBox, studentId);
    _sync.immediatePush('delete_student', studentId, {'id': studentId, 'code': studentCode});
    notifyListeners();
  }

  void updateStudentId(String oldCode, String newId) {
    final idx = _students.indexWhere((s) => s.id == oldCode);
    if (idx == -1) return;
    final oldData = LocalDB.getData(LocalDB.studentsBox, _students[idx].code);
    _students[idx] = StudentModel(
      id: newId, code: _students[idx].code, fullName: _students[idx].fullName,
      phone: _students[idx].phone, parentPhone: _students[idx].parentPhone,
      parentPhone2: _students[idx].parentPhone2, gradeLevel: _students[idx].gradeLevel,
      groupId: _students[idx].groupId, isPaid: _students[idx].isPaid,
      hasPin: _students[idx].hasPin, createdAt: _students[idx].createdAt,
    );
    if (oldData != null) { oldData['id'] = newId; LocalDB.saveData(LocalDB.studentsBox, _students[idx].code, oldData); }
    notifyListeners();
  }

  List<StudentModel> filterStudents({String? search, String? groupId}) {
    var filtered = _students;
    if (groupId != null && groupId.isNotEmpty) filtered = filtered.where((s) => s.groupId == groupId).toList();
    if (search != null && search.isNotEmpty) {
      filtered = filtered.where((s) =>
          s.fullName.toLowerCase().contains(search.toLowerCase()) ||
          s.code.toLowerCase().contains(search.toLowerCase())).toList();
    }
    return filtered;
  }
}
