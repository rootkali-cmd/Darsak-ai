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
  bool hasPin;
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
    this.hasPin = false,
    required this.createdAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      parentPhone: json['parent_phone']?.toString(),
      parentPhone2: json['parent_phone2']?.toString(),
      gradeLevel: json['grade_level']?.toString(),
      groupId: json['group_id']?.toString(),
      isPaid: json['is_paid'] ?? false,
      hasPin: json['has_pin'] ?? false,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
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
        'has_pin': hasPin,
        'created_at': createdAt.toIso8601String(),
      };

  String get initials => fullName.isNotEmpty ? fullName[0] : '?';
}
