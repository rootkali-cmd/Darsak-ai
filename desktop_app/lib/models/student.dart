class StudentModel {
  final String id;
  final String code;
  final String fullName;
  final String? phone;
  final String? parentPhone;
  final String? parentPhone2;
  final String? gradeLevel;
  final String? groupId;
  final bool isPaid;
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
    this.isPaid = false,
    required this.createdAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'],
      code: json['code'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'],
      parentPhone: json['parent_phone'],
      parentPhone2: json['parent_phone2'],
      gradeLevel: json['grade_level'],
      groupId: json['group_id'],
      isPaid: json['is_paid'] ?? false,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'full_name': fullName,
        'phone': phone,
        'parent_phone': parentPhone,
        'parent_phone2': parentPhone2,
        'grade_level': gradeLevel,
        'group_id': groupId,
        'is_paid': isPaid,
        'created_at': createdAt.toIso8601String(),
      };

  String get initials => fullName.isNotEmpty ? fullName[0] : '?';
}
