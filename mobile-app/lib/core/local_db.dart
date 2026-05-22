import 'package:hive_flutter/hive_flutter.dart';

class LocalDB {
  static const String gradesBox = 'cached_grades';
  static const String attendanceBox = 'cached_attendance';
  static const String invoicesBox = 'cached_invoices';
  static const String profileBox = 'cached_profile';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(gradesBox);
    await Hive.openBox<Map>(attendanceBox);
    await Hive.openBox<Map>(invoicesBox);
    await Hive.openBox<Map>(profileBox);
  }

  static void saveList(String boxName, List<Map<String, dynamic>> items) {
    final box = Hive.box<Map>(boxName);
    box.clear();
    for (final item in items) {
      final id = item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      box.put(id, item);
    }
  }

  static List<Map<String, dynamic>> getList(String boxName) {
    final box = Hive.box<Map>(boxName);
    return box.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static void saveProfile(Map<String, dynamic> data) {
    Hive.box<Map>(profileBox).put('me', data);
  }

  static Map<String, dynamic>? getProfile() {
    final data = Hive.box<Map>(profileBox).get('me');
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  static void clearAll() {
    Hive.box<Map>(gradesBox).clear();
    Hive.box<Map>(attendanceBox).clear();
    Hive.box<Map>(invoicesBox).clear();
    Hive.box<Map>(profileBox).clear();
  }
}
