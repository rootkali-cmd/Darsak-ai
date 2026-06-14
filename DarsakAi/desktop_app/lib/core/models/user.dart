class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? teacherCode;
  final bool isActive;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.teacherCode,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'teacher',
      teacherCode: json['teacher_code']?.toString(),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'role': role,
        'teacher_code': teacherCode,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  String get initials => fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
}
