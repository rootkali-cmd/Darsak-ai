import 'package:flutter_test/flutter_test.dart';
import 'package:darsak_mobile/models/student.dart';
import 'package:darsak_mobile/models/grade.dart';
import 'package:darsak_mobile/models/attendance.dart';
import 'package:darsak_mobile/models/invoice.dart';

void main() {
  group('StudentModel', () {
    test('fromJson creates model correctly', () {
      final json = {
        'id': 'stu-1',
        'code': 'ST001',
        'full_name': 'Ahmed Ali',
        'phone': '0100000000',
        'parent_phone': '0111111111',
        'parent_phone2': null,
        'grade_level': 'أولى ثانوي',
        'group_id': 'grp1',
        'teacher_id': 'tch1',
        'created_at': '2026-01-15T10:00:00',
      };
      final student = StudentModel.fromJson(json);
      expect(student.id, 'stu-1');
      expect(student.code, 'ST001');
      expect(student.fullName, 'Ahmed Ali');
      expect(student.phone, '0100000000');
      expect(student.parentPhone, '0111111111');
      expect(student.parentPhone2, isNull);
      expect(student.gradeLevel, 'أولى ثانوي');
      expect(student.groupId, 'grp1');
      expect(student.teacherId, 'tch1');
      expect(student.createdAt, DateTime(2026, 1, 15, 10, 0, 0));
    });

    test('fromJson handles missing fields gracefully', () {
      final json = <String, dynamic>{};
      final student = StudentModel.fromJson(json);
      expect(student.id, '');
      expect(student.code, '');
      expect(student.fullName, '');
      expect(student.phone, isNull);
      expect(student.createdAt, isA<DateTime>());
    });

    test('initials returns first character of fullName', () {
      final student = StudentModel(
        id: '1', code: 'ST001', fullName: 'Ahmed',
        createdAt: DateTime(2026),
      );
      expect(student.initials, 'A');
    });

    test('initials returns ? for empty fullName', () {
      final student = StudentModel(
        id: '1', code: 'ST001', fullName: '',
        createdAt: DateTime(2026),
      );
      expect(student.initials, '?');
    });

    test('fromJson handles invalid date gracefully', () {
      final json = {'created_at': 'invalid-date'};
      final student = StudentModel.fromJson(json);
      expect(student.createdAt, isA<DateTime>());
    });
  });

  group('GradeModel', () {
    test('fromJson creates model correctly', () {
      final json = {
        'id': 'g1',
        'exam_name': 'امتحان رياضيات',
        'subject': 'رياضيات',
        'score': 85.0,
        'max_score': 100.0,
        'created_at': '2026-03-01T09:00:00',
      };
      final grade = GradeModel.fromJson(json);
      expect(grade.id, 'g1');
      expect(grade.examName, 'امتحان رياضيات');
      expect(grade.subject, 'رياضيات');
      expect(grade.score, 85.0);
      expect(grade.maxScore, 100.0);
    });

    test('percentage calculates correctly', () {
      final grade = GradeModel(
        id: '1', examName: 'Test', subject: 'Math',
        score: 85, maxScore: 100, createdAt: DateTime(2026),
      );
      expect(grade.percentage, 85.0);
    });

    test('percentage handles zero maxScore', () {
      final grade = GradeModel(
        id: '1', examName: 'Test', subject: 'Math',
        score: 85, maxScore: 0, createdAt: DateTime(2026),
      );
      expect(grade.percentage, 0);
    });

    test('toJson serializes correctly', () {
      final grade = GradeModel(
        id: 'g1', examName: 'Test', subject: 'Math',
        score: 85, maxScore: 100, createdAt: DateTime(2026, 3, 1),
      );
      final json = grade.toJson();
      expect(json['id'], 'g1');
      expect(json['score'], 85.0);
      expect(json['max_score'], 100.0);
      expect(json['created_at'], isA<String>());
    });

    test('fromJson handles missing score defaults to 0', () {
      final json = <String, dynamic>{};
      final grade = GradeModel.fromJson(json);
      expect(grade.score, 0);
      expect(grade.maxScore, 100);
    });
  });

  group('AttendanceModel', () {
    test('fromJson creates model correctly', () {
      final json = {
        'id': 'a1',
        'status': 'present',
        'date': '2026-03-15T08:00:00',
        'group_id': 'grp1',
        'notes': 'ملاحظة',
      };
      final att = AttendanceModel.fromJson(json);
      expect(att.id, 'a1');
      expect(att.status, 'present');
      expect(att.date, '2026-03-15');
      expect(att.groupId, 'grp1');
      expect(att.notes, 'ملاحظة');
    });

    test('statusLabel returns Arabic for present', () {
      final att = AttendanceModel(
        id: '1', status: 'present', date: '2026-01-01',
      );
      expect(att.statusLabel, 'حاضر');
    });

    test('statusLabel returns Arabic for absent', () {
      final att = AttendanceModel(
        id: '1', status: 'absent', date: '2026-01-01',
      );
      expect(att.statusLabel, 'غائب');
    });

    test('statusLabel returns Arabic for cancelled', () {
      final att = AttendanceModel(
        id: '1', status: 'cancelled', date: '2026-01-01',
      );
      expect(att.statusLabel, 'ملغي');
    });

    test('statusLabel returns raw status for unknown', () {
      final att = AttendanceModel(
        id: '1', status: 'late', date: '2026-01-01',
      );
      expect(att.statusLabel, 'late');
    });

    test('fromJson strips time from date', () {
      final json = {'date': '2026-03-15T14:30:00.000Z'};
      final att = AttendanceModel.fromJson(json);
      expect(att.date, '2026-03-15');
    });

    test('toJson serializes correctly', () {
      final att = AttendanceModel(
        id: 'a1', status: 'present', date: '2026-03-15',
        groupId: 'grp1', notes: 'note',
      );
      final json = att.toJson();
      expect(json['id'], 'a1');
      expect(json['status'], 'present');
      expect(json['group_id'], 'grp1');
    });
  });

  group('InvoiceModel', () {
    test('fromJson creates model correctly', () {
      final json = {
        'id': 'inv1',
        'amount': 500.0,
        'description': 'شهر مارس',
        'paid': true,
        'payment_date': '2026-03-10',
        'created_at': '2026-03-01T09:00:00',
      };
      final inv = InvoiceModel.fromJson(json);
      expect(inv.id, 'inv1');
      expect(inv.amount, 500.0);
      expect(inv.description, 'شهر مارس');
      expect(inv.paid, true);
      expect(inv.paymentDate, '2026-03-10');
    });

    test('month returns YYYY-MM format', () {
      final inv = InvoiceModel(
        id: '1', amount: 100, paid: false,
        createdAt: DateTime(2026, 3, 15),
      );
      expect(inv.month, '2026-03');
    });

    test('month pads single digit month', () {
      final inv = InvoiceModel(
        id: '1', amount: 100, paid: false,
        createdAt: DateTime(2026, 1, 15),
      );
      expect(inv.month, '2026-01');
    });

    test('toJson serializes correctly', () {
      final inv = InvoiceModel(
        id: 'inv1', amount: 500, description: 'test',
        paid: true, paymentDate: '2026-03-10',
        createdAt: DateTime(2026, 3, 1),
      );
      final json = inv.toJson();
      expect(json['id'], 'inv1');
      expect(json['amount'], 500.0);
      expect(json['paid'], true);
    });

    test('fromJson handles missing paid defaults to false', () {
      final json = <String, dynamic>{};
      final inv = InvoiceModel.fromJson(json);
      expect(inv.paid, false);
      expect(inv.amount, 0);
    });
  });
}
