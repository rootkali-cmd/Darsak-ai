import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'api_service.dart';

class UpdateService {
  static const String _remindLaterKey = 'update_remind_later';
  static const String _updateUrl = 'https://darsakai.com/api/update/check';
  static const String _downloadBase = 'https://github.com/rootkali-cmd/Darsak-ai/releases/download';

  Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await Dio().get(
        _updateUrl,
        options: Options(
          headers: {'Accept': 'application/json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        final latestVersion = data['latest_version'] as String? ?? '';
        final currentVersion = await getCurrentVersion();

        if (_isNewer(latestVersion, currentVersion)) {
          return {
            ...data,
            'current_version': currentVersion,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<String?> downloadAndInstall({
    required String version,
    required void Function(double progress) onProgress,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/DarsakAI-Teacher-v$version.apk';
      final file = File(filePath);

      final downloadUrl = '$_downloadBase/v$version/DarsakAI-Teacher-v$version.apk';

      final api = ApiService();
      await api.dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
        options: Options(
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );

      if (await file.exists()) {
        final result = await OpenFilex.open(filePath, type: 'application/vnd.android.package-archive');
        if (result.type == ResultType.done) {
          return filePath;
        }
        return null;
      }
      return null;
    } catch (e) {
      rethrow;
    }
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
