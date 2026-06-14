class AttendanceModel {
  final String id;
  final String studentId;
  final String? groupId;
  final String status;
  final String date;
  final String? notes;

  const AttendanceModel({
    required this.id,
    required this.studentId,
    this.groupId,
    required this.status,
    required this.date,
    this.notes,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      groupId: json['group_id']?.toString(),
      status: json['status']?.toString() ?? '',
      date: json['date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'group_id': groupId,
        'status': status,
        'date': date,
        'notes': notes,
      };

  String get statusLabel {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'absent':
        return 'غائب';
      case 'cancelled':
        return 'ملغي';
      default:
        return status;
    }
  }
}
