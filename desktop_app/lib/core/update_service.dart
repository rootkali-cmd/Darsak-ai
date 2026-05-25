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
  final bool mandatory;
  final List<String> changelog;
  final List<String> changelogEn;
  final String? downloadUrl;
  final int? sizeMb;
  final String? releaseDate;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.mandatory,
    required this.changelog,
    required this.changelogEn,
    this.downloadUrl,
    this.sizeMb,
    this.releaseDate,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['changelog'];
    final rawEn = json['changelog_en'];
    return UpdateInfo(
      version: json['version'] as String? ?? '',
      build: json['build'] as int? ?? 0,
      mandatory: json['mandatory'] as bool? ?? false,
      changelog: raw is List ? raw.cast<String>() : [],
      changelogEn: rawEn is List ? rawEn.cast<String>() : [],
      downloadUrl: json['download_url'] as String?,
      sizeMb: json['size_mb'] as int?,
      releaseDate: json['release_date'] as String?,
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
  installing,
  error,
}

class UpdateService extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  UpdateStatus _status = UpdateStatus.upToDate;
  UpdateInfo? _updateInfo;
  double _downloadProgress = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _cachedDownloadPath;
  bool _ignoredVersion = false;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get errorMessage => _errorMessage;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;
  bool get isUpToDate => _status == UpdateStatus.upToDate;
  bool get isReadyToInstall => _status == UpdateStatus.readyToInstall;
  bool get isError => _status == UpdateStatus.error;
  bool get isInstalling => _status == UpdateStatus.installing;

  String get downloadSpeed {
    if (_totalBytes <= 0 || _downloadProgress <= 0) return '';
    final elapsed = _downloadProgress * 10;
    if (elapsed <= 0) return '';
    final bytesPerSec = _downloadedBytes / elapsed;
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }

  String get downloadPercent {
    return '${(_downloadProgress * 100).toStringAsFixed(0)}%';
  }

  String get downloadedSize {
    if (_totalBytes <= 0) return '';
    final mb = _downloadedBytes / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(_downloadedBytes / 1024).toStringAsFixed(0)} KB';
  }

  String get totalSize {
    if (_totalBytes <= 0) return '';
    final mb = _totalBytes / (1024 * 1024);
    return mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(_totalBytes / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> checkForUpdate({bool force = false}) async {
    if (_status == UpdateStatus.checking) return;

    if (_ignoredVersion && !force) return;

    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('/versions/${AppConstants.platformName}');
      if (response.statusCode != 200) {
        _status = UpdateStatus.upToDate;
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

      final prefs = await SharedPreferences.getInstance();
      _ignoredVersion = prefs.getString('ignored_update_version') == latest.version;

      if (_ignoredVersion && !latest.mandatory) {
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
      _status = UpdateStatus.upToDate;
    }

    notifyListeners();
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      final maxLen = latestParts.length > currentParts.length
          ? latestParts.length
          : currentParts.length;

      while (latestParts.length < maxLen) latestParts.add(0);
      while (currentParts.length < maxLen) currentParts.add(0);

      for (int i = 0; i < maxLen; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> ignoreVersion() async {
    if (_updateInfo == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ignored_update_version', _updateInfo!.version);
    _ignoredVersion = true;
    _status = UpdateStatus.upToDate;
    _updateInfo = null;
    notifyListeners();
  }

  Future<void> downloadUpdate() async {
    if (_updateInfo?.downloadUrl == null) return;

    _status = UpdateStatus.downloading;
    _downloadProgress = 0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      final dir = await getApplicationSupportDirectory();
      final downloadDir = Directory('${dir.path}/updates');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final fileName = _updateInfo!.downloadUrl!.split('/').last;
      final filePath = '${downloadDir.path}/$fileName';

      if (File(filePath).existsSync()) {
        await File(filePath).delete();
      }

      _cachedDownloadPath = filePath;

      await _dio.download(
        _updateInfo!.downloadUrl!,
        filePath,
        onReceiveProgress: (received, total) {
          _downloadedBytes = received;
          _totalBytes = total;
          if (total > 0) {
            _downloadProgress = received / total;
          }
          notifyListeners();
        },
      );

      final downloadedFile = File(filePath);
      if (!await downloadedFile.exists() || await downloadedFile.length() == 0) {
        _status = UpdateStatus.error;
        _errorMessage = 'فشل التحميل - الملف تالف';
        notifyListeners();
        return;
      }

      _status = UpdateStatus.readyToInstall;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = 'فشل التحميل';
    }

    notifyListeners();
  }

  Future<void> installUpdate() async {
    if (_cachedDownloadPath == null) return;

    _status = UpdateStatus.installing;
    notifyListeners();

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
        exit(0);
      } else if (Platform.isLinux) {
        final dir = await getApplicationSupportDirectory();
        final extractDir = '${dir.path}/extracted';
        final extractDirectory = Directory(extractDir);
        if (await extractDirectory.exists()) {
          await extractDirectory.delete(recursive: true);
        }
        await extractDirectory.create(recursive: true);

        await Process.run(
          'tar',
          ['-xzf', file.path, '-C', extractDir],
          runInShell: true,
        );

        final appDir = Directory(extractDir);
        final files = await appDir.list(recursive: true).toList();
        for (final f in files) {
          if (f is File) {
            final relativePath = f.path.replaceAll('${appDir.path}/', '');
            if (relativePath == 'darsak_desktop') {
              await f.copy('/opt/darsakai/darsak_desktop');
              await Process.run('chmod', ['+x', '/opt/darsakai/darsak_desktop']);
            }
          }
        }

        if (await extractDirectory.exists()) {
          await extractDirectory.delete(recursive: true);
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
    _downloadProgress = 0;
    notifyListeners();
  }

  void retry() {
    if (_errorMessage != null) {
      checkForUpdate(force: true);
    }
  }
}
