import 'dart:convert';
import 'dart:io' as io;
import 'package:sqlite3/sqlite3.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/student.dart';
import '../../models/group.dart';

class DatabaseService {
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

  Future<void> init(String dbPath) async {
    if (_initialized) return;
    final dir = p.dirname(dbPath);
    final dirFile = io.Directory(dir);
    if (!await dirFile.exists()) {
      await dirFile.create(recursive: true);
    }
    _db = sqlite3.open(dbPath);
    _configure();
    _createTables();
    _initialized = true;
  }

  void _configure() {
    db.execute('PRAGMA journal_mode=WAL');
    db.execute('PRAGMA foreign_keys=ON');
    db.execute('PRAGMA synchronous=NORMAL');
    db.execute('PRAGMA cache_size=-8000');
  }

  void _createTables() {
    db.execute('''
      CREATE TABLE IF NOT EXISTS students (
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
    db.execute('CREATE INDEX IF NOT EXISTS idx_students_group ON students(group_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_students_id ON students(id)');

    db.execute('''
      CREATE TABLE IF NOT EXISTS groups_tbl (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL DEFAULT '',
        subject TEXT NOT NULL DEFAULT '',
        level TEXT NOT NULL DEFAULT '',
        day_of_week TEXT NOT NULL DEFAULT '',
        time_slot TEXT NOT NULL DEFAULT ''
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS attendance (
        id TEXT NOT NULL PRIMARY KEY,
        student_id TEXT NOT NULL,
        group_id TEXT,
        status TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        notes TEXT
      )
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_att_student ON attendance(student_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_att_date ON attendance(date)');

    db.execute('''
      CREATE TABLE IF NOT EXISTS grades (
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
    db.execute('CREATE INDEX IF NOT EXISTS idx_grade_student ON grades(student_id)');
    db.execute('CREATE INDEX IF NOT EXISTS idx_grade_code ON grades(student_code)');

    db.execute('''
      CREATE TABLE IF NOT EXISTS invoices (
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
    db.execute('CREATE INDEX IF NOT EXISTS idx_inv_student ON invoices(student_id)');

    db.execute('''
      CREATE TABLE IF NOT EXISTS payments (
        student_id TEXT NOT NULL,
        month_key TEXT NOT NULL,
        is_paid INTEGER NOT NULL DEFAULT 0,
        amount REAL,
        paid_at TEXT,
        PRIMARY KEY (student_id, month_key)
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        operation_id TEXT,
        timestamp TEXT NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    db.execute('CREATE INDEX IF NOT EXISTS idx_queue_synced ON sync_queue(synced)');

    db.execute('''
      CREATE TABLE IF NOT EXISTS dead_letter (
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

    db.execute('''
      CREATE TABLE IF NOT EXISTS sync_cursors (
        table_name TEXT NOT NULL PRIMARY KEY,
        cursor TEXT NOT NULL
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT NOT NULL PRIMARY KEY,
        value TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE IF NOT EXISTS conflict_logs (
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
  }

  // ── Migration state ──────────────────────────────────────────
  int? getSchemaVersion() {
    final result = db.select('SELECT value FROM settings WHERE key=?', ['schema_version']);
    if (result.isNotEmpty) return int.tryParse(result.first['value'] as String);
    return null;
  }

  void setSchemaVersion(int version) {
    db.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', ['schema_version', version.toString()]);
  }

  // ── Students ─────────────────────────────────────────────────
  List<StudentModel> getAllStudents() {
    final rows = db.select('SELECT * FROM students ORDER BY full_name ASC');
    return rows.map((r) => _rowToStudent(r)).toList();
  }

  StudentModel? getStudent(String code) {
    final rows = db.select('SELECT * FROM students WHERE code=?', [code]);
    if (rows.isEmpty) return null;
    return _rowToStudent(rows.first);
  }

  StudentModel? getStudentById(String id) {
    final rows = db.select('SELECT * FROM students WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return _rowToStudent(rows.first);
  }

  void saveStudent(StudentModel s) {
    db.execute(
      'INSERT OR REPLACE INTO students (code, id, full_name, phone, parent_phone, parent_phone2, grade_level, group_id, is_paid, has_pin, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)',
      [s.code, s.id, s.fullName, s.phone, s.parentPhone, s.parentPhone2, s.gradeLevel, s.groupId, s.isPaid ? 1 : 0, s.hasPin ? 1 : 0, s.createdAt.toIso8601String()],
    );
  }

  void deleteStudent(String code) {
    db.execute('DELETE FROM students WHERE code=?', [code]);
  }

  void deleteStudentById(String id) {
    db.execute('DELETE FROM students WHERE id=?', [id]);
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
    final rows = db.select('SELECT * FROM students $where ORDER BY full_name ASC', params);
    return rows.map((r) => _rowToStudent(r)).toList();
  }

  int getStudentCount() {
    final result = db.select('SELECT COUNT(*) AS cnt FROM students');
    return result.first['cnt'] as int;
  }

  StudentModel _rowToStudent(Row r) {
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

  // ── Groups ───────────────────────────────────────────────────
  List<GroupModel> getAllGroups() {
    final rows = db.select('SELECT * FROM groups_tbl ORDER BY name ASC');
    return rows.map((r) => _rowToGroup(r)).toList();
  }

  GroupModel? getGroup(String id) {
    final rows = db.select('SELECT * FROM groups_tbl WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return _rowToGroup(rows.first);
  }

  void saveGroup(GroupModel g) {
    db.execute(
      'INSERT OR REPLACE INTO groups_tbl (id, name, subject, level, day_of_week, time_slot) VALUES (?,?,?,?,?,?)',
      [g.id, g.name, g.subject, g.level, g.dayOfWeek, g.timeSlot],
    );
  }

  void deleteGroup(String id) {
    db.execute('DELETE FROM groups_tbl WHERE id=?', [id]);
  }

  GroupModel _rowToGroup(Row r) {
    return GroupModel(
      id: r['id'] as String? ?? '',
      name: r['name'] as String? ?? '',
      subject: r['subject'] as String? ?? '',
      level: r['level'] as String? ?? '',
      dayOfWeek: r['day_of_week'] as String? ?? '',
      timeSlot: r['time_slot'] as String? ?? '',
    );
  }

  // ── Attendance ───────────────────────────────────────────────
  List<Map<String, dynamic>> getAllAttendance() {
    final rows = db.select('SELECT * FROM attendance ORDER BY date DESC');
    return rows.map((r) => _rowToMap(r, ['id', 'student_id', 'group_id', 'status', 'date', 'notes'])).toList();
  }

  Map<String, dynamic>? getAttendance(String id) {
    final rows = db.select('SELECT * FROM attendance WHERE id=?', [id]);
    if (rows.isEmpty) return null;
    return _rowToMap(rows.first, ['id', 'student_id', 'group_id', 'status', 'date', 'notes']);
  }

  void saveAttendance(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? const Uuid().v4();
    data['id'] = id;
    db.execute(
      'INSERT OR REPLACE INTO attendance (id, student_id, group_id, status, date, notes) VALUES (?,?,?,?,?,?)',
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

  // ── Grades ───────────────────────────────────────────────────
  List<Map<String, dynamic>> getAllGrades() {
    final rows = db.select('SELECT * FROM grades ORDER BY created_at DESC');
    return rows.map((r) => _rowToMap(r, ['id', 'student_id', 'student_code', 'exam_name', 'subject', 'score', 'max_score', 'wrong_questions', 'notes', 'created_at'])).toList();
  }

  void saveGrade(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? const Uuid().v4();
    data['id'] = id;
    final wrongQ = data['wrong_questions'] != null ? jsonEncode(data['wrong_questions']) : null;
    db.execute(
      'INSERT OR REPLACE INTO grades (id, student_id, student_code, exam_name, subject, score, max_score, wrong_questions, notes, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
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

  // ── Invoices ─────────────────────────────────────────────────
  List<Map<String, dynamic>> getAllInvoices() {
    final rows = db.select('SELECT * FROM invoices ORDER BY created_at DESC');
    return rows.map((r) => _rowToMap(r, ['id', 'student_id', 'amount', 'description', 'paid', 'payment_date', 'signature', 'created_at'])).toList();
  }

  void saveInvoice(Map<String, dynamic> data) {
    final id = data['id']?.toString() ?? const Uuid().v4();
    data['id'] = id;
    db.execute(
      'INSERT OR REPLACE INTO invoices (id, student_id, amount, description, paid, payment_date, signature, created_at) VALUES (?,?,?,?,?,?,?,?)',
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

  // ── Payments ─────────────────────────────────────────────────
  Map<String, dynamic>? getPayment(String studentId, String monthKey) {
    final rows = db.select('SELECT * FROM payments WHERE student_id=? AND month_key=?', [studentId, monthKey]);
    if (rows.isEmpty) return null;
    return _rowToMap(rows.first, ['student_id', 'month_key', 'is_paid', 'amount', 'paid_at']);
  }

  void savePayment(Map<String, dynamic> data) {
    db.execute(
      'INSERT OR REPLACE INTO payments (student_id, month_key, is_paid, amount, paid_at) VALUES (?,?,?,?,?)',
      [
        data['student_id']?.toString() ?? '',
        data['month_key']?.toString() ?? '',
        data['is_paid'] == true ? 1 : 0,
        data['amount']?.toDouble(),
        data['paid_at']?.toString(),
      ],
    );
  }

  // ── Sync Queue ───────────────────────────────────────────────
  void addToSyncQueue(String type, Map<String, dynamic> data, {String? operationId}) {
    db.execute(
      'INSERT INTO sync_queue (type, data, operation_id, timestamp, synced, retry_count) VALUES (?,?,?,?,0,0)',
      [type, jsonEncode(data), operationId, DateTime.now().toIso8601String()],
    );
  }

  List<Map<String, dynamic>> getUnsyncedItems() {
    final rows = db.select('SELECT * FROM sync_queue WHERE synced=0 ORDER BY id ASC');
    return rows.map((r) => {
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
    db.execute('UPDATE sync_queue SET synced=1 WHERE operation_id=?', [operationId]);
  }

  void markSyncedByData(Map<String, dynamic> targetData) {
    final targetId = targetData['id']?.toString();
    final targetCode = targetData['code']?.toString();
    final targetOpId = targetData['operation_id']?.toString();
    if (targetOpId != null) {
      db.execute('UPDATE sync_queue SET synced=1 WHERE operation_id=?', [targetOpId]);
      return;
    }
    final rows = db.select('SELECT * FROM sync_queue WHERE synced=0 ORDER BY id ASC');
    for (final r in rows) {
      final itemData = jsonDecode(r['data'] as String) as Map<String, dynamic>;
      final itemOpId = r['operation_id'] as String?;
      final itemId = itemData['id']?.toString();
      final itemCode = itemData['code']?.toString();
      if ((targetOpId != null && targetOpId == itemOpId) ||
          (targetId != null && targetId == itemId) ||
          (targetCode != null && targetCode == itemCode)) {
        final id = r['id'] as int;
        db.execute('UPDATE sync_queue SET synced=1 WHERE id=?', [id]);
        return;
      }
    }
  }

  void clearSyncedItems() {
    db.execute('DELETE FROM sync_queue WHERE synced=1');
  }

  int get syncQueueLength {
    final r = db.select('SELECT COUNT(*) AS cnt FROM sync_queue');
    return r.first['cnt'] as int;
  }

  int get unsyncedCount {
    final r = db.select('SELECT COUNT(*) AS cnt FROM sync_queue WHERE synced=0');
    return r.first['cnt'] as int;
  }

  // ── Dead Letter ──────────────────────────────────────────────
  void addToDeadLetter(Map<String, dynamic> item, {String? error}) {
    db.execute(
      'INSERT INTO dead_letter (type, data, operation_id, timestamp, synced, retry_count, dead_letter_at, error) VALUES (?,?,?,?,?,?,?,?)',
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
    final rows = db.select('SELECT * FROM dead_letter ORDER BY id ASC');
    return rows.map((r) => {
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
    db.execute('DELETE FROM dead_letter WHERE operation_id=?', [operationId]);
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
      db.execute('DELETE FROM dead_letter');
    }
  }

  int get deadLetterCount {
    final r = db.select('SELECT COUNT(*) AS cnt FROM dead_letter');
    return r.first['cnt'] as int;
  }

  // ── Sync Cursors ─────────────────────────────────────────────
  String? getCursor(String table) {
    final rows = db.select('SELECT cursor FROM sync_cursors WHERE table_name=?', [table]);
    if (rows.isEmpty) return null;
    return rows.first['cursor'] as String?;
  }

  void saveCursor(String table, String cursor) {
    db.execute('INSERT OR REPLACE INTO sync_cursors (table_name, cursor) VALUES (?,?)', [table, cursor]);
  }

  Map<String, String> getAllCursors() {
    final rows = db.select('SELECT * FROM sync_cursors');
    return {for (final r in rows) r['table_name'] as String: r['cursor'] as String};
  }

  // ── Settings ─────────────────────────────────────────────────
  String? getSetting(String key) {
    final rows = db.select('SELECT value FROM settings WHERE key=?', [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  void setSetting(String key, String value) {
    db.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?,?)', [key, value]);
  }

  DateTime? getLastSyncTime() {
    final v = getSetting('last_sync_time');
    if (v != null) return DateTime.tryParse(v);
    return null;
  }

  void setLastSyncTime(DateTime time) {
    setSetting('last_sync_time', time.toIso8601String());
  }

  // ── Generic helpers ──────────────────────────────────────────
  void saveGenericData(String boxName, String key, Map<String, dynamic> data) {
    switch (boxName) {
      case 'students':
        final s = StudentModel.fromJson(data);
        saveStudent(s);
      case 'groups':
        final g = GroupModel.fromJson(data);
        saveGroup(g);
      case LocalDBConst.attendanceBox:
        saveAttendance(data);
      case LocalDBConst.gradesBox:
        saveGrade(data);
      case LocalDBConst.invoicesBox:
        saveInvoice(data);
      case LocalDBConst.paymentsBox:
        savePayment(data);
    }
  }

  Map<String, dynamic>? getGenericData(String boxName, String key) {
    switch (boxName) {
      case 'students':
        final s = getStudent(key);
        return s?.toJson();
      case 'groups':
        final g = getGroup(key);
        return g?.toJson();
      case LocalDBConst.attendanceBox:
        return getAttendance(key);
      case LocalDBConst.paymentsBox:
        final parts = key.split('_');
        if (parts.length >= 2) {
          final sid = parts.sublist(0, parts.length - 1).join('_');
          final mk = parts.last;
          return getPayment(sid, mk);
        }
        return null;
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> getAllGenericData(String boxName) {
    switch (boxName) {
      case 'students':
        return getAllStudents().map((s) => s.toJson()).toList();
      case 'groups':
        return getAllGroups().map((g) => g.toJson()).toList();
      case LocalDBConst.attendanceBox:
        return getAllAttendance();
      case LocalDBConst.gradesBox:
        return getAllGrades();
      case LocalDBConst.invoicesBox:
        return getAllInvoices();
      default:
        return [];
    }
  }

  void deleteGenericData(String boxName, String key) {
    switch (boxName) {
      case 'students':
        deleteStudent(key);
      case 'groups':
        deleteGroup(key);
      case LocalDBConst.attendanceBox:
        db.execute('DELETE FROM attendance WHERE id=?', [key]);
      case LocalDBConst.gradesBox:
        db.execute('DELETE FROM grades WHERE id=?', [key]);
      case LocalDBConst.invoicesBox:
        db.execute('DELETE FROM invoices WHERE id=?', [key]);
      case LocalDBConst.paymentsBox:
        final parts = key.split('_');
        if (parts.length >= 2) {
          final sid = parts.sublist(0, parts.length - 1).join('_');
          final mk = parts.last;
          db.execute('DELETE FROM payments WHERE student_id=? AND month_key=?', [sid, mk]);
        }
    }
  }

  Map<String, dynamic> _rowToMap(Row r, List<String> columns) {
    final map = <String, dynamic>{};
    for (final c in columns) {
      final v = r.containsKey(c) ? r[c] : null;
      if (v is int) {
        if (c == 'paid' || c == 'is_paid') {
          map[c] = v == 1;
        } else if (c == 'score' || c == 'max_score' || c == 'amount') {
          map[c] = (v as int).toDouble();
        } else {
          map[c] = v;
        }
      } else if (v is double) {
        map[c] = v;
      } else {
        map[c] = v?.toString();
      }
    }
    return map;
  }

  void close() {
    _db?.dispose();
    _db = null;
    _initialized = false;
  }
}

class LocalDBConst {
  static const String attendanceBox = 'attendance';
  static const String gradesBox = 'grades';
  static const String invoicesBox = 'invoices';
  static const String paymentsBox = 'payments';
}
