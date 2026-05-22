class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? teacherCode;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
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
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      role: json['role'],
      teacherCode: json['teacher_code'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
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
