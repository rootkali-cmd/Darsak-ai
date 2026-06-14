class AttendanceModel {
  final String id;
  final String status;
  final String date;
  final String? groupId;
  final String? notes;

  AttendanceModel({
    required this.id,
    required this.status,
    required this.date,
    this.groupId,
    this.notes,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      status: json['status'] ?? 'absent',
      date: (json['date'] ?? '').toString().split('T')[0],
      groupId: json['group_id']?.toString(),
      notes: json['notes'],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'present': return 'حاضر';
      case 'absent': return 'غائب';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'date': date,
        'group_id': groupId,
        'notes': notes,
      };
}
