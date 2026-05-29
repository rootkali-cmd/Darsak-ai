import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

void main() {
  late Database _db;

  setUp(() {
    _db = sqlite3.open(':memory:');
    _db.execute('PRAGMA journal_mode=WAL');
    _db.execute('PRAGMA foreign_keys=ON');
  });

  tearDown(() {
    _db.dispose();
  });

  group('Database Schema', () {
    test('creates all tables', () {
      _createTables(_db);
      final tables = _db.select(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names, contains('students'));
      expect(names, contains('groups_tbl'));
      expect(names, contains('attendance'));
      expect(names, contains('grades'));
      expect(names, contains('invoices'));
      expect(names, contains('payments'));
      expect(names, contains('sync_queue'));
      expect(names, contains('dead_letter'));
      expect(names, contains('sync_cursors'));
      expect(names, contains('settings'));
    });
  });

  group('Students', () {
    test('insert and retrieve student', () {
      _createTables(_db);
      _db.execute(
        'INSERT INTO students (code, id, full_name, phone, parent_phone, grade_level, group_id, is_paid, has_pin, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
        ['ST001', 'ST001', 'Ahmed', '0100000000', '0111111111', 'أولى ثانوي', 'grp1', 0, 0, '2026-01-01T00:00:00'],
      );
      final rows = _db.select('SELECT * FROM students WHERE code=?', ['ST001']);
      expect(rows.length, 1);
      expect(rows.first['full_name'] as String, 'Ahmed');
      expect(rows.first['is_paid'] as int, 0);
    });

    test('insert duplicate code replaces', () {
      _createTables(_db);
      _db.execute(
        'INSERT INTO students (code, id, full_name, phone, parent_phone, grade_level, group_id, is_paid, has_pin, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
        ['ST001', 'ST001', 'Ahmed', '0100000000', null, null, null, 0, 0, '2026-01-01T00:00:00'],
      );
      _db.execute(
        'INSERT OR REPLACE INTO students (code, id, full_name, phone, parent_phone, grade_level, group_id, is_paid, has_pin, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
        ['ST001', 'ST001', 'Mohamed', '0100000001', null, null, null, 1, 1, '2026-02-01T00:00:00'],
      );
      final rows = _db.select('SELECT * FROM students WHERE code=?', ['ST001']);
      expect(rows.length, 1);
      expect(rows.first['full_name'] as String, 'Mohamed');
    });
  });

  group('Sync Queue', () {
    test('insert and retrieve unsynced items', () {
      _createTables(_db);
      _db.execute(
        'INSERT INTO sync_queue (type, data, operation_id, timestamp, synced, retry_count) VALUES (?,?,?,?,0,0)',
        ['student', '{"name":"test"}', const Uuid().v4(), '2026-01-01T00:00:00'],
      );
      _db.execute(
        'INSERT INTO sync_queue (type, data, operation_id, timestamp, synced, retry_count) VALUES (?,?,?,?,1,0)',
        ['student', '{"name":"synced"}', const Uuid().v4(), '2026-01-01T00:00:00'],
      );

      final unsynced = _db.select('SELECT * FROM sync_queue WHERE synced=0');
      expect(unsynced.length, 1);

      final synced = _db.select('SELECT * FROM sync_queue WHERE synced=1');
      expect(synced.length, 1);
    });

    test('mark as synced by operation_id', () {
      _createTables(_db);
      final opId = 'test-op-123';
      _db.execute(
        'INSERT INTO sync_queue (type, data, operation_id, timestamp, synced, retry_count) VALUES (?,?,?,?,0,0)',
        ['student', '{}', opId, '2026-01-01T00:00:00'],
      );
      _db.execute('UPDATE sync_queue SET synced=1 WHERE operation_id=?', [opId]);
      final rows = _db.select('SELECT * FROM sync_queue WHERE synced=1');
      expect(rows.length, 1);
    });

    test('clears synced items', () {
      _createTables(_db);
      _db.execute(
        'INSERT INTO sync_queue (type, data, operation_id, timestamp, synced, retry_count) VALUES (?,?,?,?,1,0)',
        ['student', '{}', 'op1', '2026-01-01T00:00:00'],
      );
      _db.execute('DELETE FROM sync_queue WHERE synced=1');
      final rows = _db.select('SELECT * FROM sync_queue');
      expect(rows.length, 0);
    });
  });

  group('Dead Letter', () {
    test('insert and retrieve dead letters', () {
      _createTables(_db);
      _db.execute(
        'INSERT INTO dead_letter (type, data, operation_id, timestamp, synced, retry_count, dead_letter_at, error) VALUES (?,?,?,?,?,?,?,?)',
        ['student', '{}', 'dl-op-1', '2026-01-01T00:00:00', 0, 3, '2026-01-02T00:00:00', 'timeout'],
      );
      final rows = _db.select('SELECT * FROM dead_letter');
      expect(rows.length, 1);
      expect(rows.first['error'] as String, 'timeout');
    });
  });

  group('Grades', () {
    test('insert and retrieve grades with score conversion', () {
      _createTables(_db);
      _db.execute(
        'INSERT OR REPLACE INTO grades (id, student_id, student_code, exam_name, subject, score, max_score, wrong_questions, notes, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
        ['g1', 'ST001', 'ST001', 'امتحان 1', 'رياضيات', 85.0, 100.0, null, null, '2026-01-01T00:00:00'],
      );
      final rows = _db.select('SELECT * FROM grades WHERE id=?', ['g1']);
      expect(rows.length, 1);
      expect(rows.first['score'] as double, 85.0);
    });
  });

  group('Indexes', () {
    test('students index on group_id exists', () {
      _createTables(_db);
      final indexes = _db.select(
        "SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='students'",
      );
      final names = indexes.map((r) => r['name'] as String).toList();
      expect(names, contains('idx_students_group'));
    });
  });
}

/// Creates all tables matching the production schema.
void _createTables(Database db) {
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
