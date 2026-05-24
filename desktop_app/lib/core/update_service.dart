import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class UpdateInfo {
  final String version;
  final int build;
  final String? downloadUrl;
  final int? sizeMb;
  final String changesAr;
  final String changesEn;
  final bool forceUpdate;

  UpdateInfo({
    required this.version,
    required this.build,
    this.downloadUrl,
    this.sizeMb,
    required this.changesAr,
    required this.changesEn,
    required this.forceUpdate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    return UpdateInfo(
      version: json['version'] as String? ?? '',
      build: json['build'] as int? ?? 0,
      downloadUrl: json['download_url'] as String?,
      sizeMb: json['size_mb'] as int?,
      changesAr: json['changes_ar'] as String? ?? '',
      changesEn: json['changes_en'] as String? ?? '',
      forceUpdate: json['force_update'] as bool? ?? false,
    );
  }

  bool get isValid => version.isNotEmpty && downloadUrl != null;
}

enum UpdateStatus {
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  error,
}

class UpdateService extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  UpdateStatus _status = UpdateStatus.upToDate;
  UpdateInfo? _updateInfo;
  double _downloadProgress = 0;
  String? _errorMessage;
  String? _cachedDownloadPath;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;

  Future<void> checkForUpdate() async {
    if (_status == UpdateStatus.checking) return;

    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('/versions/desktop');
      if (response.statusCode != 200) {
        _status = UpdateStatus.error;
        _errorMessage = 'فشل الاتصال بالخادم';
        notifyListeners();
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final latest = UpdateInfo.fromJson(data);

      if (!latest.isValid) {
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      final currentVersion = AppConstants.appVersion;
      if (_isNewerVersion(latest.version, currentVersion)) {
        _updateInfo = latest;
        _status = UpdateStatus.available;
      } else {
        _status = UpdateStatus.upToDate;
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = 'خطأ في التحقق من التحديثات';
    }

    notifyListeners();
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return latestParts.length > currentParts.length;
    } catch (_) {
      return false;
    }
  }

  Future<void> downloadUpdate() async {
    if (_updateInfo?.downloadUrl == null) return;

    _status = UpdateStatus.downloading;
    _downloadProgress = 0;
    notifyListeners();

    try {
      final dir = await getApplicationSupportDirectory();
      final fileName = _updateInfo!.downloadUrl!.split('/').last;
      final filePath = '${dir.path}/$fileName';
      _cachedDownloadPath = filePath;

      await _dio.download(
        _updateInfo!.downloadUrl!,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            notifyListeners();
          }
        },
      );

      _status = UpdateStatus.readyToInstall;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = 'فشل التحميل';
    }

    notifyListeners();
  }

  Future<void> installUpdate() async {
    if (_cachedDownloadPath == null) return;

    try {
      final file = File(_cachedDownloadPath!);
      if (!await file.exists()) {
        _status = UpdateStatus.error;
        _errorMessage = 'ملف التحديث غير موجود';
        notifyListeners();
        return;
      }

      if (Platform.isWindows) {
        await Process.run(
          file.path,
          ['/SILENT', '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
          runInShell: true,
        );
      } else if (Platform.isLinux) {
        final dir = await getApplicationSupportDirectory();
        final extractDir = dir.path;
        await Process.run(
          'tar',
          ['-xzf', file.path, '-C', extractDir],
          runInShell: true,
        );
        final appDir = Directory(extractDir);
        final files = await appDir.list().toList();
        for (final f in files) {
          if (f is File) {
            await f.copy('/opt/darsakai/darsak_desktop');
          }
        }
      }

      _status = UpdateStatus.upToDate;
      _cachedDownloadPath = null;
      _updateInfo = null;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = 'فشل التثبيت';
    }

    notifyListeners();
  }

  void dismiss() {
    _status = UpdateStatus.upToDate;
    _updateInfo = null;
    _errorMessage = null;
    notifyListeners();
  }
}
