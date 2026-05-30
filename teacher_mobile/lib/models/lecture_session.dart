/// Represents a lecture session that spans multiple groups and days.
/// 
/// Example: "Algebra Chapter 3" session:
/// - Group 1: Saturday 10:00 AM
/// - Group 2: Sunday 10:00 AM
/// - Group 3: Monday 5:00 PM
/// 
/// A student is considered present if they attend ANY scheduled occurrence.
class LectureSession {
  final String id;
  final String name;
  final String? description;
  final List<SessionSchedule> schedules;
  final bool isActive;
  final DateTime createdAt;

  LectureSession({
    required this.id,
    required this.name,
    this.description,
    required this.schedules,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'schedules': schedules.map((s) => s.toJson()).toList(),
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  factory LectureSession.fromJson(Map<String, dynamic> json) => LectureSession(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    schedules: (json['schedules'] as List).map((s) => SessionSchedule.fromJson(s as Map<String, dynamic>)).toList(),
    isActive: json['is_active'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['created_at'] as String) ?? DateTime.now(),
  );

  /// Get all groups participating in this session
  List<String> get groupIds => schedules.map((s) => s.groupId).toSet().toList();

  /// Check if this session has a schedule for a specific group and date
  bool hasScheduleFor(String groupId, DateTime date) {
    final weekday = date.weekday; // 1=Monday, 7=Sunday
    return schedules.any((s) => 
      s.groupId == groupId && 
      s.dayOfWeek == weekday &&
      s.isActive
    );
  }

  /// Get schedule for a specific group
  SessionSchedule? getScheduleForGroup(String groupId) {
    try {
      return schedules.firstWhere((s) => s.groupId == groupId);
    } catch (_) {
      return null;
    }
  }
}

/// A single scheduled occurrence of a session for a specific group.
class SessionSchedule {
  final String groupId;
  final String groupName;
  final int dayOfWeek; // 1=Monday, 7=Sunday
  final String timeSlot;
  final bool isActive;

  SessionSchedule({
    required this.groupId,
    required this.groupName,
    required this.dayOfWeek,
    required this.timeSlot,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'group_name': groupName,
    'day_of_week': dayOfWeek,
    'time_slot': timeSlot,
    'is_active': isActive,
  };

  factory SessionSchedule.fromJson(Map<String, dynamic> json) => SessionSchedule(
    groupId: json['group_id'] as String,
    groupName: json['group_name'] as String,
    dayOfWeek: json['day_of_week'] as int,
    timeSlot: json['time_slot'] as String,
    isActive: json['is_active'] as bool? ?? true,
  );

  String get dayName {
    const days = ['', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
    return days[dayOfWeek.clamp(1, 7)];
  }
}
