import 'package:flutter/foundation.dart';
import '../core/api_service.dart';
import '../core/local_db.dart';
import '../models/grade.dart';
import '../models/attendance.dart';
import '../models/invoice.dart';

class DataProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  List<GradeModel> _grades = [];
  List<AttendanceModel> _attendance = [];
  List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;

  List<GradeModel> get grades => _grades;
  List<AttendanceModel> get attendance => _attendance;
  List<InvoiceModel> get invoices => _invoices;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  double get attendanceRate {
    if (_attendance.isEmpty) return 0;
    final present = _attendance.where((a) => a.status == 'present').length;
    return (present / _attendance.length) * 100;
  }

  double get averageGrade {
    if (_grades.isEmpty) return 0;
    final total = _grades.fold<double>(0, (sum, g) => sum + g.percentage);
    return total / _grades.length;
  }

  List<GradeModel> get pendingExams =>
      _grades.where((g) => g.percentage < 50).toList();

  AttendanceModel? get todayAttendance {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _attendance.where((a) => a.date == today).firstOrNull;
  }

  List<String> get subjects =>
      _grades.map((g) => g.subject).toSet().toList()..sort();

  List<GradeModel> gradesBySubject(String subject) =>
      _grades.where((g) => g.subject == subject).toList();

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Load from cache first
    _loadFromCache();

    // Try API
    await Future.wait([
      fetchGrades(),
      fetchAttendance(),
      fetchInvoices(),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  void _loadFromCache() {
    final cachedGrades = LocalDB.getList(LocalDB.gradesBox);
    if (cachedGrades.isNotEmpty) {
      _grades = cachedGrades.map((g) => GradeModel.fromJson(g)).toList();
    }
    final cachedAttendance = LocalDB.getList(LocalDB.attendanceBox);
    if (cachedAttendance.isNotEmpty) {
      _attendance = cachedAttendance.map((a) => AttendanceModel.fromJson(a)).toList();
    }
    final cachedInvoices = LocalDB.getList(LocalDB.invoicesBox);
    if (cachedInvoices.isNotEmpty) {
      _invoices = cachedInvoices.map((i) => InvoiceModel.fromJson(i)).toList();
    }
  }

  Future<void> fetchGrades({String? subject}) async {
    try {
      final data = await _api.getGrades(subject: subject);
      _grades = data.map((g) => GradeModel.fromJson(g as Map<String, dynamic>)).toList();
      LocalDB.saveList(LocalDB.gradesBox, _grades.map((g) => g.toJson()).toList());
      _isOffline = false;
    } catch (_) {
      _isOffline = true;
    }
  }

  Future<void> fetchAttendance() async {
    try {
      final data = await _api.getAttendance();
      _attendance = data.map((a) => AttendanceModel.fromJson(a as Map<String, dynamic>)).toList();
      LocalDB.saveList(LocalDB.attendanceBox, _attendance.map((a) => a.toJson()).toList());
    } catch (_) {}
  }

  Future<void> fetchInvoices() async {
    try {
      final data = await _api.getInvoices();
      _invoices = data.map((i) => InvoiceModel.fromJson(i as Map<String, dynamic>)).toList();
      LocalDB.saveList(LocalDB.invoicesBox, _invoices.map((i) => i.toJson()).toList());
    } catch (_) {}
  }

  bool get isPaidThisMonth {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _invoices.any((i) => i.paid && i.month == month);
  }
}
