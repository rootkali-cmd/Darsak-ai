class GradeModel {
  final String id;
  final String studentId;
  final String? studentCode;
  final String examName;
  final String subject;
  final double score;
  final double maxScore;
  final List<int>? wrongQuestions;
  final String? notes;
  final DateTime createdAt;

  const GradeModel({
    required this.id,
    required this.studentId,
    this.studentCode,
    required this.examName,
    required this.subject,
    required this.score,
    required this.maxScore,
    this.wrongQuestions,
    this.notes,
    required this.createdAt,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentCode: json['student_code']?.toString(),
      examName: json['exam_name']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      score: (json['score'] ?? 0).toDouble(),
      maxScore: (json['max_score'] ?? 100).toDouble(),
      wrongQuestions: _parseWrongQuestions(json['wrong_questions']),
      notes: json['notes']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'student_code': studentCode,
        'exam_name': examName,
        'subject': subject,
        'score': score,
        'max_score': maxScore,
        'wrong_questions': wrongQuestions,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0;

  static List<int>? _parseWrongQuestions(dynamic value) {
    if (value == null) return null;
    if (value is List) return List<int>.from(value.map((e) => (e as num).toInt()));
    if (value is String) {
      try {
        final cleaned = value.replaceAll('[', '').replaceAll(']', '').trim();
        if (cleaned.isEmpty) return null;
        return cleaned.split(',').map((e) => int.parse(e.trim())).toList();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
