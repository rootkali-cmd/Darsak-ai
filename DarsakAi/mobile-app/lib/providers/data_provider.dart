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
  Map<String, dynamic> _examStats = {};
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;

  List<GradeModel> get grades => _allGrades;
  List<GradeModel> get manualGrades => _grades;
  List<AttendanceModel> get attendance => _attendance;
  List<InvoiceModel> get invoices => _invoices;
  Map<String, dynamic> get examStats => _examStats;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;

  List<GradeModel> get _allGrades {
    final merged = <GradeModel>[..._grades];
    final examRecent = _examStats['recent_results'] as List<dynamic>? ?? [];
    for (final r in examRecent) {
      merged.add(GradeModel(
        id: r['student_exam_id']?.toString() ?? '',
        examName: r['exam_title'] ?? 'اختبار',
        subject: 'اختبارات',
        score: (r['score'] ?? 0).toDouble(),
        maxScore: (r['max_score'] ?? 0).toDouble(),
        createdAt: DateTime.tryParse(r['submitted_at'] ?? '') ?? DateTime.now(),
      ));
    }
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return merged;
  }

  double get attendanceRate {
    if (_attendance.isEmpty) return 0;
    final present = _attendance.where((a) => a.status == 'present').length;
    return (present / _attendance.length) * 100;
  }

  double get averageGrade {
    final allScores = <double>[];
    if (_grades.isNotEmpty) {
      allScores.addAll(_grades.map((g) => g.percentage));
    }
    final examAvg = (_examStats['average_score'] ?? 0).toDouble();
    final examCount = (_examStats['total_exams_taken'] ?? 0) as int;
    if (examCount > 0) {
      allScores.addAll(List.filled(examCount, examAvg));
    }
    if (allScores.isEmpty) return 0;
    return allScores.reduce((a, b) => a + b) / allScores.length;
  }

  int get totalExamsAndGrades {
    final examCount = (_examStats['total_exams_taken'] ?? 0) as int;
    return _grades.length + examCount;
  }

  double get bestScore {
    final allScores = <double>[];
    if (_grades.isNotEmpty) {
      allScores.addAll(_grades.map((g) => g.percentage));
    }
    final examBest = (_examStats['best_score'] ?? 0).toDouble();
    if (examBest > 0) allScores.add(examBest);
    if (allScores.isEmpty) return 0;
    return allScores.reduce((a, b) => a > b ? a : b);
  }

  double get worstScore {
    final allScores = <double>[];
    if (_grades.isNotEmpty) {
      allScores.addAll(_grades.map((g) => g.percentage));
    }
    final examWorst = (_examStats['worst_score'] ?? 0).toDouble();
    if (examWorst > 0) allScores.add(examWorst);
    if (allScores.isEmpty) return 0;
    return allScores.reduce((a, b) => a < b ? a : b);
  }

  List<GradeModel> get lowGrades =>
      _allGrades.where((g) => g.percentage < 50).toList();

  int get lowGradesCount {
    int count = _grades.where((g) => g.percentage < 50).length;
    final examRecent = _examStats['recent_results'] as List<dynamic>? ?? [];
    for (final r in examRecent) {
      final pct = (r['percentage'] ?? 0).toDouble();
      if (pct < 50) count++;
    }
    return count;
  }

  List<Map<String, dynamic>> get recentResults {
    final results = <Map<String, dynamic>>[];
    for (final g in _grades.take(5)) {
      results.add({
        'name': g.examName,
        'subject': g.subject,
        'score': g.score,
        'max_score': g.maxScore,
        'percentage': g.percentage,
        'type': 'grade',
      });
    }
    final examRecent = _examStats['recent_results'] as List<dynamic>? ?? [];
    for (final r in examRecent) {
      results.add({
        'name': r['exam_title'] ?? 'اختبار',
        'subject': 'اختبار',
        'score': r['score'] ?? 0,
        'max_score': r['max_score'] ?? 0,
        'percentage': r['percentage'] ?? 0,
        'type': 'exam',
      });
    }
    results.sort((a, b) => (b['percentage'] as double).compareTo(a['percentage'] as double));
    return results.take(2).toList();
  }

  AttendanceModel? get todayAttendance {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _attendance.where((a) => a.date == today).firstOrNull;
  }

  List<String> get subjects =>
      _allGrades.map((g) => g.subject).toSet().toList()..sort();

  List<GradeModel> gradesBySubject(String subject) =>
      _allGrades.where((g) => g.subject == subject).toList();

  List<GradeModel> get examResults {
    final examRecent = _examStats['recent_results'] as List<dynamic>? ?? [];
    return examRecent.map((r) => GradeModel(
      id: r['student_exam_id']?.toString() ?? '',
      examName: r['exam_title'] ?? 'اختبار',
      subject: 'اختبارات',
      score: (r['score'] ?? 0).toDouble(),
      maxScore: (r['max_score'] ?? 0).toDouble(),
      createdAt: DateTime.tryParse(r['submitted_at'] ?? '') ?? DateTime.now(),
    )).toList();
  }

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
      fetchExamStats(),
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

  Future<void> fetchExamStats() async {
    try {
      final data = await _api.getStudentStats();
      _examStats = data;
    } catch (_) {
      _examStats = {};
    }
  }

  bool get isPaidThisMonth {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return _invoices.any((i) => i.paid && i.month == month);
  }
}
