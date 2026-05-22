class AttendanceModel {
  final String id;
  final String studentId;
  final String? groupId;
  final String status;
  final String date;
  final String? notes;

  AttendanceModel({
    required this.id,
    required this.studentId,
    this.groupId,
    required this.status,
    required this.date,
    this.notes,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'],
      studentId: json['student_id'],
      groupId: json['group_id'],
      status: json['status'],
      date: json['date'] ?? DateTime.now().toIso8601String().split('T')[0],
      notes: json['notes'],
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
      case 'present': return 'حاضر';
      case 'absent': return 'غائب';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }
}
