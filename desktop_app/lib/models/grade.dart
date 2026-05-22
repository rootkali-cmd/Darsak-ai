class GradeModel {
  final String id;
  final String studentId;
  final String examName;
  final String subject;
  final double score;
  final double maxScore;
  final List<int>? wrongQuestions;
  final String? notes;
  final DateTime createdAt;

  GradeModel({
    required this.id,
    required this.studentId,
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
      id: json['id'],
      studentId: json['student_id'],
      examName: json['exam_name'],
      subject: json['subject'],
      score: (json['score'] ?? 0).toDouble(),
      maxScore: (json['max_score'] ?? 100).toDouble(),
      wrongQuestions: json['wrong_questions'] != null
          ? List<int>.from(json['wrong_questions'])
          : null,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'exam_name': examName,
        'subject': subject,
        'score': score,
        'max_score': maxScore,
        'wrong_questions': wrongQuestions,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0;
}
