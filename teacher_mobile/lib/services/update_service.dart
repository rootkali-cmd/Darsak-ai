import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class UpdateService {
  static const String _remindLaterKey = 'update_remind_later';

  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final api = ApiService();
      final response = await api.dio.get('https://darsakai.com/api/update/check');
      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final latestVersion = data['latest_version'] as String? ?? '';
        final currentVersion = await getCurrentVersion();

        if (_isNewer(latestVersion, currentVersion)) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  bool _isNewer(String latest, String current) {
    final l = latest.split('.').map(int.tryParse).toList();
    final c = current.split('.').map(int.tryParse).toList();
    for (int i = 0; i < 3; i++) {
      final lv = (i < l.length ? l[i] : 0) ?? 0;
      final cv = (i < c.length ? c[i] : 0) ?? 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  Future<void> setRemindLater() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_remindLaterKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> isRemindLaterActive() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_remindLaterKey);
    if (timestamp == null) return false;
    final remindTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(remindTime).inHours < 24;
  }
}
