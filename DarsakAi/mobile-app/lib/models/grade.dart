class GradeModel {
  final String id;
  final String examName;
  final String subject;
  final double score;
  final double maxScore;
  final DateTime createdAt;

  GradeModel({
    required this.id,
    required this.examName,
    required this.subject,
    required this.score,
    required this.maxScore,
    required this.createdAt,
  });

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      id: json['id']?.toString() ?? '',
      examName: json['exam_name'] ?? '',
      subject: json['subject'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      maxScore: (json['max_score'] ?? 100).toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  double get percentage => maxScore > 0 ? (score / maxScore) * 100 : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam_name': examName,
        'subject': subject,
        'score': score,
        'max_score': maxScore,
        'created_at': createdAt.toIso8601String(),
      };
}
