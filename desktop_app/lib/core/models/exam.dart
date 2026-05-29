class ExamModel {
  final String id;
  final String title;
  final String? description;
  final int durationMinutes;
  final bool published;
  final DateTime createdAt;
  final int totalQuestions;
  final int essayQuestions;

  const ExamModel({
    required this.id,
    required this.title,
    this.description,
    required this.durationMinutes,
    this.published = false,
    required this.createdAt,
    this.totalQuestions = 0,
    this.essayQuestions = 0,
  });

  factory ExamModel.fromJson(Map<String, dynamic> json) {
    return ExamModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      durationMinutes: json['duration_minutes'] ?? 30,
      published: json['published'] ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      totalQuestions: json['total_questions'] ?? 0,
      essayQuestions: json['essay_questions'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'duration_minutes': durationMinutes,
        'published': published,
        'created_at': createdAt.toIso8601String(),
        'total_questions': totalQuestions,
        'essay_questions': essayQuestions,
      };
}

class ExamQuestionModel {
  final String id;
  final String examId;
  final int questionNumber;
  final String questionText;
  final List<String> options;
  final int correctAnswer;
  final double points;
  final String type; // 'multiple_choice' or 'essay'
  final String? studentAnswer; // for essay questions

  const ExamQuestionModel({
    required this.id,
    required this.examId,
    required this.questionNumber,
    required this.questionText,
    required this.options,
    required this.correctAnswer,
    this.points = 1.0,
    this.type = 'multiple_choice',
    this.studentAnswer,
  });

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    return ExamQuestionModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      questionNumber: json['question_number'] ?? 0,
      questionText: json['question_text']?.toString() ?? '',
      options: (json['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      correctAnswer: json['correct_answer'] ?? 0,
      points: (json['points'] ?? 1.0).toDouble(),
      type: json['type']?.toString() ?? 'multiple_choice',
      studentAnswer: json['student_answer']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam_id': examId,
        'question_number': questionNumber,
        'question_text': questionText,
        'options': options,
        'correct_answer': correctAnswer,
        'points': points,
        'type': type,
        'student_answer': studentAnswer,
      };

  bool get isEssay => type == 'essay';
  bool get isMultipleChoice => type == 'multiple_choice';
}

class ExamResultModel {
  final String id;
  final String examId;
  final String studentId;
  final String studentName;
  final double score;
  final double maxScore;
  final DateTime submittedAt;
  final List<int> wrongQuestions;
  final int totalQuestions;

  const ExamResultModel({
    required this.id,
    required this.examId,
    required this.studentId,
    required this.studentName,
    required this.score,
    required this.maxScore,
    required this.submittedAt,
    this.wrongQuestions = const [],
    this.totalQuestions = 0,
  });

  factory ExamResultModel.fromJson(Map<String, dynamic> json) {
    List<int> wrong = [];
    if (json['wrong_questions'] is List) {
      wrong = (json['wrong_questions'] as List).map((e) => (e as num).toInt()).toList();
    }
    return ExamResultModel(
      id: json['id']?.toString() ?? '',
      examId: json['exam_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? '',
      score: (json['score'] ?? 0).toDouble(),
      maxScore: (json['max_score'] ?? 100).toDouble(),
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? '') ?? DateTime.now(),
      wrongQuestions: wrong,
      totalQuestions: json['total_questions'] ?? 0,
    );
  }

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0;
}
