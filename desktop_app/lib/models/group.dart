class GroupModel {
  final String id;
  final String name;
  final String subject;
  final String level;
  final String dayOfWeek;
  final String timeSlot;

  GroupModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.level,
    required this.dayOfWeek,
    required this.timeSlot,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'],
      name: json['name'],
      subject: json['subject'],
      level: json['level'],
      dayOfWeek: json['day_of_week'],
      timeSlot: json['time_slot'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subject': subject,
        'level': level,
        'day_of_week': dayOfWeek,
        'time_slot': timeSlot,
      };
}
