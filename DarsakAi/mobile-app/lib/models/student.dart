class StudentModel {
  final String id;
  final String code;
  final String fullName;
  final String? phone;
  final String? parentPhone;
  final String? parentPhone2;
  final String? gradeLevel;
  final String? groupId;
  final String? teacherId;
  final DateTime createdAt;

  StudentModel({
    required this.id,
    required this.code,
    required this.fullName,
    this.phone,
    this.parentPhone,
    this.parentPhone2,
    this.gradeLevel,
    this.groupId,
    this.teacherId,
    required this.createdAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id']?.toString() ?? '',
      code: json['code'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      parentPhone: json['parent_phone'],
      parentPhone2: json['parent_phone2'],
      gradeLevel: json['grade_level'],
      groupId: json['group_id']?.toString(),
      teacherId: json['teacher_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  String get initials => fullName.isNotEmpty ? fullName[0] : '?';
}
