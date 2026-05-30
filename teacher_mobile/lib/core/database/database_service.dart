import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/constants.dart';
import '../models/student.dart';
import '../models/group.dart';

final class DatabaseService {
  DatabaseService._();
  static final DatabaseService _instance = DatabaseService._();
  static DatabaseService get instance => _instance;

  Database? _db;
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Database get db {
    if (_db == null) throw StateError('DatabaseService not initialized');
    return _db!;
  }

  Future<void> init() async {
    if (_initialized) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'darsak_teacher.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
        await _createIndexes(db);
      },
    );
    _initialized = true;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.studentsTable} (
        code TEXT NOT NULL PRIMARY KEY,
        id TEXT NOT NULL,
        full_name TEXT NOT NULL DEFAULT '',
        phone TEXT,
        parent_phone TEXT,
        parent_phone2 TEXT,
        grade_level TEXT,
        group_id TEXT,
        is_paid INTEGER NOT NULL DEFAULT 0,
        has_pin INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.groupsTable} (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        subject TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        day_of_week TEXT NOT NULL DEFAULT '',
        time_slot TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.attendanceTable} (
        id TEXT NOT NULL PRIMARY KEY,
        student_id TEXT NOT NULL,
        group_id TEXT,
        status TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.gradesTable} (
        id TEXT NOT NULL PRIMARY KEY,
        student_id TEXT,
        student_code TEXT,
        exam_name TEXT NOT NULL DEFAULT '',
        subject TEXT NOT NULL DEFAULT '',
        score REAL NOT NULL DEFAULT 0,
        max_score REAL NOT NULL DEFAULT 100,
        wrong_questions TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.invoicesTable} (
        id TEXT NOT NULL PRIMARY KEY,
        student_id TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        description TEXT,
        paid INTEGER NOT NULL DEFAULT 0,
        payment_date TEXT,
        signature TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.paymentsTable} (
        student_id TEXT NOT NULL,
        month_key TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        amount REAL,
        paid_at TEXT,
        PRIMARY KEY (student_id, month_key)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.syncQueueTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        operation_id TEXT,
        timestamp TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.deadLetterTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        operation_id TEXT,
        timestamp TEXT,
        synced INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        dead_letter_at TEXT NOT NULL,
        error TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.syncCursorsTable} (
        table_name TEXT NOT NULL PRIMARY KEY,
        cursor TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.settingsTable} (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.conflictLogsTable} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        box TEXT,
        key TEXT,
        winner TEXT,
        resolver TEXT,
        local_device TEXT,
        remote_device TEXT,
        local_data TEXT,
        remote_data TEXT,
        timestamp TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.examsTable} (
        id TEXT NOT NULL PRIMARY KEY,
        title TEXT NOT NULL DEFAULT '',
        description TEXT,
        duration_minutes INTEGER NOT NULL DEFAULT 30,
        published INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.examQuestionsTable} (
        id TEXT NOT NULL PRIMARY KEY,
        exam_id TEXT NOT NULL,
        question_number INTEGER NOT NULL DEFAULT 0,
        question_text TEXT NOT NULL DEFAULT '',
        options TEXT,
        correct_answer INTEGER NOT NULL DEFAULT 0,
        points REAL NOT NULL DEFAULT 1.0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.examResultsTable} (
        id TEXT NOT NULL PRIMARY KEY,
        exam_id TEXT NOT NULL,
        student_id TEXT NOT NULL,
        student_name TEXT NOT NULL DEFAULT '',
        score REAL NOT NULL DEFAULT 0,
        max_score REAL NOT NULL DEFAULT 100,
        submitted_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    final indexes = [
      'CREATE INDEX IF NOT EXISTS idx_students_group ON ${DbConstants.studentsTable}(group_id)',
      'CREATE INDEX IF NOT EXISTS idx_students_id ON ${DbConstants.studentsTable}(id)',
      'CREATE INDEX IF NOT EXISTS idx_students_name ON ${DbConstants.studentsTable}(full_name)',
      'CREATE INDEX IF NOT EXISTS idx_students_code ON ${DbConstants.studentsTable}(code)',
      'CREATE INDEX IF NOT EXISTS idx_att_student ON ${DbConstants.attendanceTable}(student_id)',
      'CREATE INDEX IF NOT EXISTS idx_att_date ON ${DbConstants.attendanceTable}(date)',
      'CREATE INDEX IF NOT EXISTS idx_grade_student ON ${DbConstants.gradesTable}(student_id)',
      'CREATE INDEX IF NOT EXISTS idx_grade_code ON ${DbConstants.gradesTable}(student_code)',
      'CREATE INDEX IF NOT EXISTS idx_grade_created ON ${DbConstants.gradesTable}(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_inv_student ON ${DbConstants.invoicesTable}(student_id)',
      'CREATE INDEX IF NOT EXISTS idx_inv_created ON ${DbConstants.invoicesTable}(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_queue_synced ON ${DbConstants.syncQueueTable}(synced)',
      'CREATE INDEX IF NOT EXISTS idx_queue_opid ON ${DbConstants.syncQueueTable}(operation_id)',
      'CREATE INDEX IF NOT EXISTS idx_deadletter_opid ON ${DbConstants.deadLetterTable}(operation_id)',
      'CREATE INDEX IF NOT EXISTS idx_exam_published ON ${DbConstants.examsTable}(published)',
      'CREATE INDEX IF NOT EXISTS idx_exam_created ON ${DbConstants.examsTable}(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_question_exam ON ${DbConstants.examQuestionsTable}(exam_id)',
      'CREATE INDEX IF NOT EXISTS idx_result_exam ON ${DbConstants.examResultsTable}(exam_id)',
      'CREATE INDEX IF NOT EXISTS idx_result_student ON ${DbConstants.examResultsTable}(student_id)',
    ];
    for (final idx in indexes) {
      await db.execute(idx);
    }
  }

  // ── Students ──
  List<StudentModel> getAllStudents() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.studentsTable} ORDER BY full_name ASC');
    return rows.map(_rowToStudent).toList();
  }

  StudentModel? getStudent(String code) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.studentsTable} WHERE code=?', [code]);
    if (rows.isEmpty) return null;
    return _rowToStudent(rows.first);
  }

  StudentModel? getStudentById(String id) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.studentsTable} WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return _rowToStudent(rows.first);
  }

  void saveStudent(StudentModel s) {
    db.rawInsert(
      'INSERT OR REPLACE INTO ${DbConstants.studentsTable} (code, id, full_name, phone, parent_phone, parent_phone2, grade_level, group_id, is_paid, has_pin, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [s.code, s.id, s.fullName, s.phone, s.parentPhone, s.parentPhone2, s.gradeLevel, s.groupId, s.isPaid ? 1 : 0, s.hasPin ? 1 : 0, s.createdAt.toIso8601String()],
    );
  }

  void deleteStudent(String code) {
    db.rawDelete('DELETE FROM ${DbConstants.studentsTable} WHERE code=?', [code]);
  }

  void deleteStudentById(String id) {
    db.rawDelete('DELETE FROM ${DbConstants.studentsTable} WHERE id=?', [id]);
  }

  List<StudentModel> searchStudents({String? search, String? groupId}) {
    final conditions = <String>[];
    final params = <Object?>[];
    if (search != null && search.isNotEmpty) {
      conditions.add('(full_name LIKE ? OR code LIKE ?)');
      params.add('%$search%');
      params.add('%$search%');
    }
    if (groupId != null && groupId.isNotEmpty) {
      conditions.add('group_id=?');
      params.add(groupId);
    }
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.studentsTable} $where ORDER BY full_name ASC', params);
    return rows.map(_rowToStudent).toList();
  }

  int getStudentCount() {
    final result = db.rawQuery('SELECT COUNT(*) AS cnt FROM ${DbConstants.studentsTable}');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  StudentModel _rowToStudent(Map<String, dynamic> r) {
    return StudentModel(
      id: r['id'] as String? ?? '',
      code: r['code'] as String? ?? '',
      fullName: r['full_name'] as String? ?? '',
      phone: r['phone'] as String?,
      parentPhone: r['parent_phone'] as String?,
      parentPhone2: r['parent_phone2'] as String?,
      gradeLevel: r['grade_level'] as String?,
      groupId: r['group_id'] as String?,
      isPaid: (r['is_paid'] as int?) == 1,
      hasPin: (r['has_pin'] as int?) == 1,
      createdAt: DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  // ── Groups ──
  List<GroupModel> getAllGroups() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.groupsTable} ORDER BY name ASC');
    return rows.map(_rowToGroup).toList();
  }

  GroupModel? getGroup(String id) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.groupsTable} WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return _rowToGroup(rows.first);
  }

  void saveGroup(GroupModel g) {
    db.rawInsert(
      'INSERT OR REPLACE INTO ${DbConstants.groupsTable} (id, name, subject, level, day_of_week, time_slot) VALUES (?,?,?,?,?,?)',
      [g.id, g.name, g.subject, g.level, g.dayOfWeek, g.timeSlot],
    );
  }

  void deleteGroup(String id) {
    db.rawDelete('DELETE FROM ${DbConstants.groupsTable} WHERE id=?', [id]);
  }

  GroupModel _rowToGroup(Map<String, dynamic> r) {
    return GroupModel(
      id: r['id'] as String? ?? '',
      name: r['name'] as String? ?? '',
      subject: r['subject'] as String? ?? '',
      level: r['level'] as String? ?? '',
      dayOfWeek: r['day_of_week'] as String? ?? '',
      timeSlot: r['time_slot'] as String? ?? '',
    );
  }

  // ── Attendance ──
  List<Map<String, dynamic>> getAllAttendance() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.attendanceTable} ORDER BY date DESC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getAttendance(String id) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.attendanceTable} WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void saveAttendance(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? const Uuid().v4();
    data['id'] = id;
    db.rawInsert(
      'INSERT OR REPLACE INTO ${DbConstants.attendanceTable} (id, student_id, group_id, status, date, notes) VALUES (?,?,?,?,?,?)',
      [
        id,
        data['student_id']?.toString() ?? '',
        data['group_id']?.toString(),
        data['status']?.toString() ?? '',
        data['date']?.toString() ?? '',
        data['notes']?.toString(),
      ],
    );
  }

  // ── Grades ──
  List<Map<String, dynamic>> getAllGrades() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.gradesTable} ORDER BY created_at DESC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getGrade(String id) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.gradesTable} WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void saveGrade(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? const Uuid().v4();
    data['id'] = id;
    final wrongQ = data['wrong_questions'] != null ? jsonEncode(data['wrong_questions']) : null;
    db.rawInsert(
      'INSERT OR REPLACE INTO ${DbConstants.gradesTable} (id, student_id, student_code, exam_name, subject, score, max_score, wrong_questions, notes, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
      [
        id,
        data['student_id']?.toString(),
        data['student_code']?.toString(),
        data['exam_name']?.toString() ?? '',
        data['subject']?.toString() ?? '',
        (data['score'] ?? 0).toDouble(),
        (data['max_score'] ?? 100).toDouble(),
        wrongQ,
        data['notes']?.toString(),
        data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ],
    );
  }

  void deleteGrade(String id) {
    db.rawDelete('DELETE FROM ${DbConstants.gradesTable} WHERE id=?', [id]);
  }

  // ── Invoices ──
  List<Map<String, dynamic>> getAllInvoices() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.invoicesTable} ORDER BY created_at DESC');
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Map<String, dynamic>? getInvoice(String id) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.invoicesTable} WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void saveInvoice(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? const Uuid().v4();
    data['id'] = id;
    db.rawInsert(
      'INSERT OR REPLACE INTO ${DbConstants.invoicesTable} (id, student_id, amount, description, paid, payment_date, signature, created_at) VALUES (?,?,?,?,?,?,?,?)',
      [
        id,
        data['student_id']?.toString() ?? '',
        (data['amount'] ?? 0).toDouble(),
        data['description']?.toString(),
        data['paid'] == true ? 1 : 0,
        data['payment_date']?.toString(),
        data['signature']?.toString(),
        data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ],
    );
  }

  void updateInvoicePaid(String id, bool paid, {String? paymentDate}) {
    db.rawUpdate(
      'UPDATE ${DbConstants.invoicesTable} SET paid=?, payment_date=? WHERE id=?',
      [paid ? 1 : 0, paymentDate, id],
    );
  }

  // ── Payments ──
  Map<String, dynamic>? getPayment(String studentId, String monthKey) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.paymentsTable} WHERE student_id=? AND month_key=?', [studentId, monthKey]);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  void savePayment(Map<String, dynamic> data) {
    db.rawInsert(
      'INSERT OR REPLACE INTO ${DbConstants.paymentsTable} (student_id, month_key, is_paid, amount, paid_at) VALUES (?,?,?,?,?)',
      [data['student_id']?.toString() ?? '', data['month_key']?.toString() ?? '', data['is_paid'] == true ? 1 : 0, data['amount']?.toDouble(), data['paid_at']?.toString()],
    );
  }

  // ── Sync Queue ──
  void addToSyncQueue(String type, Map<String, dynamic> data, {String? operationId}) {
    final opId = operationId ?? const Uuid().v4();
    final targetId = data['id']?.toString();
    final targetCode = data['code']?.toString();
    if ((targetId != null && targetId.isNotEmpty) || (targetCode != null && targetCode.isNotEmpty)) {
      final rows = db.rawQuery(
        'SELECT id, data FROM ${DbConstants.syncQueueTable} WHERE type=? AND synced=0',
        [type],
      );
      for (final r in rows) {
        final itemData = jsonDecode(r['data'] as String) as Map<String, dynamic>;
        final itemId = itemData['id']?.toString();
        final itemCode = itemData['code']?.toString();
        if ((targetId != null && targetId == itemId) || (targetCode != null && targetCode == itemCode)) {
          db.rawUpdate(
            'UPDATE ${DbConstants.syncQueueTable} SET data=?, operation_id=?, timestamp=?, retry_count=0 WHERE id=?',
            [jsonEncode(data), opId, DateTime.now().toIso8601String(), r['id']],
          );
          return;
        }
      }
    }
    db.rawInsert(
      'INSERT INTO ${DbConstants.syncQueueTable} (type, data, operation_id, timestamp, synced, retry_count) VALUES (?,?,?,?,0,0)',
      [type, jsonEncode(data), opId, DateTime.now().toIso8601String()],
    );
  }

  List<Map<String, dynamic>> getUnsyncedItems() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.syncQueueTable} WHERE synced=0 ORDER BY id ASC');
    return rows.map((r) => <String, dynamic>{
      'id': r['id'],
      'type': r['type'] as String,
      'data': jsonDecode(r['data'] as String) as Map<String, dynamic>,
      'operation_id': r['operation_id'] as String?,
      'timestamp': r['timestamp'] as String,
      'synced': r['synced'] as int,
      'retry_count': r['retry_count'] as int,
    }).toList();
  }

  void markSyncedByOpId(String operationId) {
    db.rawUpdate('UPDATE ${DbConstants.syncQueueTable} SET synced=1 WHERE operation_id=?', [operationId]);
  }

  void markSyncedByData(Map<String, dynamic> targetData) {
    final targetOpId = targetData['operation_id']?.toString();
    if (targetOpId != null && targetOpId.isNotEmpty) {
      db.rawUpdate('UPDATE ${DbConstants.syncQueueTable} SET synced=1 WHERE operation_id=?', [targetOpId]);
      return;
    }
    final targetId = targetData['id']?.toString();
    final targetCode = targetData['code']?.toString();
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.syncQueueTable} WHERE synced=0 ORDER BY id ASC');
    for (final r in rows) {
      final itemData = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      final itemOpId = r['operation_id'] as String?;
      final itemId = itemData['id']?.toString();
      final itemCode = itemData['code']?.toString();
      if ((targetOpId != null && targetOpId == itemOpId) ||
          (targetId != null && targetId == itemId) ||
          (targetCode != null && targetCode == itemCode)) {
        final id = r['id'] as int;
        db.rawUpdate('UPDATE ${DbConstants.syncQueueTable} SET synced=1 WHERE id=?', [id]);
        return;
      }
    }
  }

  void clearSyncedItems() {
    db.rawDelete('DELETE FROM ${DbConstants.syncQueueTable} WHERE synced=1');
  }

  void trimSyncQueue(int excessCount) {
    db.rawDelete(
      'DELETE FROM ${DbConstants.syncQueueTable} WHERE id IN (SELECT id FROM ${DbConstants.syncQueueTable} ORDER BY timestamp ASC LIMIT ?)',
      [excessCount],
    );
  }

  void clearAllSyncQueue() {
    db.rawDelete('DELETE FROM ${DbConstants.syncQueueTable}');
  }

  int get syncQueueLength {
    final r = db.rawQuery('SELECT COUNT(*) AS cnt FROM ${DbConstants.syncQueueTable}');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  int get unsyncedCount {
    final r = db.rawQuery('SELECT COUNT(*) AS cnt FROM ${DbConstants.syncQueueTable} WHERE synced=0');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ── Dead Letter ──
  void addToDeadLetter(Map<String, dynamic> item, {String? error}) {
    db.rawInsert(
      'INSERT INTO ${DbConstants.deadLetterTable} (type, data, operation_id, timestamp, synced, retry_count, dead_letter_at, error) VALUES (?,?,?,?,?,?,?,?)',
      [
        item['type']?.toString() ?? 'unknown',
        jsonEncode(item['data'] as Map? ?? {}),
        item['operation_id']?.toString(),
        item['timestamp']?.toString() ?? DateTime.now().toIso8601String(),
        item['synced'] ?? 0,
        item['retry_count'] ?? 0,
        DateTime.now().toIso8601String(),
        error ?? 'unknown',
      ],
    );
  }

  List<Map<String, dynamic>> getAllDeadLetters() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.deadLetterTable} ORDER BY id ASC');
    return rows.map((r) => <String, dynamic>{
      'type': r['type'] as String,
      'data': jsonDecode(r['data'] as String) as Map<String, dynamic>,
      'operation_id': r['operation_id'] as String?,
      'timestamp': r['timestamp'] as String?,
      'synced': r['synced'] as int,
      'retry_count': r['retry_count'] as int,
      'dead_letter_at': r['dead_letter_at'] as String,
      'error': r['error'] as String?,
    }).toList();
  }

  void removeDeadLetter(String operationId) {
    db.rawDelete('DELETE FROM ${DbConstants.deadLetterTable} WHERE operation_id=?', [operationId]);
  }

  void recoverDeadLetters() {
    final items = getAllDeadLetters();
    for (final item in items) {
      addToSyncQueue(
        item['type'] as String? ?? 'unknown',
        Map<String, dynamic>.from(item['data'] as Map? ?? {}),
        operationId: item['operation_id']?.toString(),
      );
    }
    if (items.isNotEmpty) {
      db.rawDelete('DELETE FROM ${DbConstants.deadLetterTable}');
    }
  }

  int get deadLetterCount {
    final r = db.rawQuery('SELECT COUNT(*) AS cnt FROM ${DbConstants.deadLetterTable}');
    return Sqflite.firstIntValue(r) ?? 0;
  }

  // ── Sync Cursors ──
  String? getCursor(String table) {
    final rows = db.rawQuery('SELECT cursor FROM ${DbConstants.syncCursorsTable} WHERE table_name=?', [table]);
    if (rows.isEmpty) return null;
    return rows.first['cursor'] as String?;
  }

  void saveCursor(String table, String cursor) {
    db.rawInsert('INSERT OR REPLACE INTO ${DbConstants.syncCursorsTable} (table_name, cursor) VALUES (?,?)', [table, cursor]);
  }

  Map<String, String> getAllCursors() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.syncCursorsTable}');
    return {for (final r in rows) r['table_name'] as String: r['cursor'] as String};
  }

  // ── Settings ──
  String? getSetting(String key) {
    final rows = db.rawQuery('SELECT value FROM ${DbConstants.settingsTable} WHERE key=?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void setSetting(String key, String value) {
    db.rawInsert('INSERT OR REPLACE INTO ${DbConstants.settingsTable} (key, value) VALUES (?,?)', [key, value]);
  }

  DateTime? getLastSyncTime() {
    final v = getSetting('last_sync_time');
    if (v != null) return DateTime.tryParse(v);
    return null;
  }

  void setLastSyncTime(DateTime time) {
    setSetting('last_sync_time', time.toIso8601String());
  }

  // ── Exams ──
  List<Map<String, dynamic>> getAllExams() {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.examsTable} ORDER BY created_at DESC');
    return rows.map((r) => <String, dynamic>{
      'id': r['id'] as String,
      'title': r['title'] as String? ?? '',
      'description': r['description'] as String?,
      'duration_minutes': r['duration_minutes'] as int? ?? 30,
      'published': (r['published'] as int?) == 1,
      'created_at': r['created_at'] as String? ?? '',
    }).toList();
  }

  Future<void> saveExams(List<Map<String, dynamic>> exams) async {
    final batch = db.batch();
    for (final e in exams) {
      batch.insert(
        DbConstants.examsTable,
        {
          'id': e['id']?.toString() ?? const Uuid().v4(),
          'title': e['title']?.toString() ?? '',
          'description': e['description']?.toString(),
          'duration_minutes': e['duration_minutes'] ?? 30,
          'published': (e['published'] == true || e['published'] == 1) ? 1 : 0,
          'created_at': e['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  void deleteAllExams() {
    db.rawDelete('DELETE FROM ${DbConstants.examsTable}');
  }

  // ── Exam Questions ──
  List<Map<String, dynamic>> getExamQuestions(String examId) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.examQuestionsTable} WHERE exam_id=? ORDER BY question_number ASC', [examId]);
    return rows.map((r) => <String, dynamic>{
      'id': r['id'] as String,
      'exam_id': r['exam_id'] as String,
      'question_number': r['question_number'] as int? ?? 0,
      'question_text': r['question_text'] as String? ?? '',
      'options': (r['options'] as String?)?.isNotEmpty == true ? jsonDecode(r['options'] as String) as List<dynamic> : <String>[],
      'correct_answer': r['correct_answer'] as int? ?? 0,
      'points': (r['points'] as num?)?.toDouble() ?? 1.0,
    }).toList();
  }

  Future<void> saveExamQuestions(String examId, List<Map<String, dynamic>> questions) async {
    db.rawDelete('DELETE FROM ${DbConstants.examQuestionsTable} WHERE exam_id=?', [examId]);
    final batch = db.batch();
    for (final q in questions) {
      batch.insert(
        DbConstants.examQuestionsTable,
        {
          'id': q['id']?.toString() ?? const Uuid().v4(),
          'exam_id': examId,
          'question_number': q['question_number'] ?? 0,
          'question_text': q['question_text']?.toString() ?? '',
          'options': q['options'] != null ? jsonEncode(q['options']) : null,
          'correct_answer': q['correct_answer'] ?? 0,
          'points': (q['points'] ?? 1.0).toDouble(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // ── Exam Results ──
  List<Map<String, dynamic>> getExamResults(String examId) {
    final rows = db.rawQuery('SELECT * FROM ${DbConstants.examResultsTable} WHERE exam_id=? ORDER BY submitted_at DESC', [examId]);
    return rows.map((r) => <String, dynamic>{
      'id': r['id'] as String,
      'exam_id': r['exam_id'] as String,
      'student_id': r['student_id'] as String,
      'student_name': r['student_name'] as String? ?? '',
      'score': (r['score'] as num?)?.toDouble() ?? 0.0,
      'max_score': (r['max_score'] as num?)?.toDouble() ?? 100.0,
      'submitted_at': r['submitted_at'] as String? ?? '',
    }).toList();
  }

  Future<void> saveExamResults(String examId, List<Map<String, dynamic>> results) async {
    db.rawDelete('DELETE FROM ${DbConstants.examResultsTable} WHERE exam_id=?', [examId]);
    final batch = db.batch();
    for (final r in results) {
      batch.insert(
        DbConstants.examResultsTable,
        {
          'id': r['id']?.toString() ?? const Uuid().v4(),
          'exam_id': examId,
          'student_id': r['student_id']?.toString() ?? '',
          'student_name': r['student_name']?.toString() ?? '',
          'score': (r['score'] ?? 0).toDouble(),
          'max_score': (r['max_score'] ?? 100).toDouble(),
          'submitted_at': r['submitted_at']?.toString() ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  void close() {
    _db?.close();
    _db = null;
    _initialized = false;
  }
}
