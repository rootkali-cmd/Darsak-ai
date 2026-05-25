import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
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
  final String? sha256;
  final String? minSupportedVersion;
  final int rollout;

  UpdateInfo({
    required this.version,
    required this.build,
    required this.mandatory,
    required this.changelog,
    required this.changelogEn,
    this.downloadUrl,
    this.sizeMb,
    this.releaseDate,
    this.sha256,
    this.minSupportedVersion,
    this.rollout = 100,
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
      sha256: json['sha256'] as String?,
      minSupportedVersion: json['min_supported_version'] as String?,
      rollout: json['rollout'] as int? ?? 100,
    );
  }

  bool get isValid => version.isNotEmpty && downloadUrl != null;

  bool get isRolledOut {
    if (rollout >= 100) return true;
    final seed = version.hashCode;
    final rng = Random(seed);
    return rng.nextInt(100) < rollout;
  }
}

enum UpdateStatus {
  checking,
  upToDate,
  available,
  downloading,
  readyToInstall,
  installing,
  restartRequired,
  error,
}

class UpdateService extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 120),
  ));

  UpdateStatus _status = UpdateStatus.upToDate;
  UpdateInfo? _updateInfo;
  double _downloadProgress = 0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  String? _errorMessage;
  String? _errorDetail;
  String? _cachedDownloadPath;
  bool _ignoredVersion = false;
  String? _lastInstalledVersion;
  int _installAttempts = 0;
  static const int _maxInstallAttempts = 3;

  UpdateStatus get status => _status;
  UpdateInfo? get updateInfo => _updateInfo;
  double get downloadProgress => _downloadProgress;
  int get downloadedBytes => _downloadedBytes;
  int get totalBytes => _totalBytes;
  String? get errorMessage => _errorMessage;
  String? get errorDetail => _errorDetail;
  bool get isChecking => _status == UpdateStatus.checking;
  bool get isDownloading => _status == UpdateStatus.downloading;
  bool get isUpToDate => _status == UpdateStatus.upToDate;
  bool get isReadyToInstall => _status == UpdateStatus.readyToInstall;
  bool get isError => _status == UpdateStatus.error;
  bool get isInstalling => _status == UpdateStatus.installing;
  bool get isRestartRequired => _status == UpdateStatus.restartRequired;

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

  Future<String> get _downloadDirPath async {
    final dir = await getApplicationSupportDirectory();
    return '${dir.path}/updates';
  }

  Future<void> checkForUpdate({bool force = false}) async {
    if (_status == UpdateStatus.checking) return;
    if (_ignoredVersion && !force) return;

    _status = UpdateStatus.checking;
    _errorMessage = null;
    _errorDetail = null;
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
      _lastInstalledVersion = prefs.getString('last_installed_version');

      if (_lastInstalledVersion == latest.version) {
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      if (_ignoredVersion && !latest.mandatory) {
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      final currentVersion = AppConstants.appVersion;
      if (!_isNewerVersion(latest.version, currentVersion)) {
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      if (latest.minSupportedVersion != null &&
          _isNewerVersion(currentVersion, latest.minSupportedVersion!)) {
        final currentParts = currentVersion.split('.').map(int.parse).toList();
        final minParts = latest.minSupportedVersion!.split('.').map(int.parse).toList();
        if (_compareVersions(currentParts, minParts) < 0) {
          _updateInfo = latest;
          _status = UpdateStatus.available;
          _errorMessage = 'إصدارك قديم جداً. يجب التحديث فوراً.';
          notifyListeners();
          return;
        }
      }

      if (!latest.isRolledOut) {
        _status = UpdateStatus.upToDate;
        notifyListeners();
        return;
      }

      if (latest.mandatory) {
        _updateInfo = latest;
        _status = UpdateStatus.available;
        notifyListeners();
        return;
      }

      _updateInfo = latest;
      _status = UpdateStatus.available;
    } catch (e) {
      _status = UpdateStatus.upToDate;
    }

    notifyListeners();
  }

  int _compareVersions(List<int> a, List<int> b) {
    final maxLen = max(a.length, b.length);
    while (a.length < maxLen) a.add(0);
    while (b.length < maxLen) b.add(0);
    for (int i = 0; i < maxLen; i++) {
      if (a[i] > b[i]) return 1;
      if (a[i] < b[i]) return -1;
    }
    return 0;
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();
      return _compareVersions(latestParts, currentParts) > 0;
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

  Future<bool> _hasSufficientDiskSpace(int requiredBytes) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final stat = await dir.stat();
      final freeBytes = stat.size;
      return freeBytes > requiredBytes * 2;
    } catch (_) {
      return true;
    }
  }

  Future<void> downloadUpdate() async {
    if (_updateInfo?.downloadUrl == null) return;

    final diskOk = await _hasSufficientDiskSpace((_updateInfo!.sizeMb ?? 50) * 1048576);
    if (!diskOk) {
      _status = UpdateStatus.error;
      _errorMessage = 'مساحة التخزين غير كافية';
      _errorDetail = 'يحتاج التحديث إلى ${_updateInfo!.sizeMb ?? 50} MB على الأقل';
      notifyListeners();
      return;
    }

    _status = UpdateStatus.downloading;
    _downloadProgress = 0;
    _downloadedBytes = 0;
    _totalBytes = 0;
    _errorMessage = null;
    _errorDetail = null;
    notifyListeners();

    try {
      final downloadDir = Directory(await _downloadDirPath);
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      await _cleanupOldDownloads(downloadDir);

      final fileName = _updateInfo!.downloadUrl!.split('/').last;
      final filePath = '${downloadDir.path}/$fileName';

      final existing = File(filePath);
      if (await existing.exists()) {
        if (_updateInfo!.sha256 != null) {
          final hash = await _computeSha256(existing);
          if (hash == _updateInfo!.sha256) {
            _cachedDownloadPath = filePath;
            _status = UpdateStatus.readyToInstall;
            notifyListeners();
            return;
          }
        }
        await existing.delete();
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
        _errorDetail = 'حجم الملف صفر أو غير موجود';
        notifyListeners();
        return;
      }

      if (_updateInfo!.sha256 != null) {
        final hash = await _computeSha256(downloadedFile);
        if (hash != _updateInfo!.sha256) {
          await downloadedFile.delete();
          _status = UpdateStatus.error;
          _errorMessage = 'توقيع الملف غير متطابق';
          _errorDetail = 'قد يكون الملف تالفاً أو تم العبث به';
          notifyListeners();
          return;
        }
      }

      _status = UpdateStatus.readyToInstall;
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = 'فشل التحميل';
      _errorDetail = e.toString();
    }

    notifyListeners();
  }

  Future<String> _computeSha256(File file) async {
    final bytes = await file.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  Future<void> _cleanupOldDownloads(Directory dir) async {
    try {
      final files = await dir.list().toList();
      for (final f in files) {
        if (f is File && f.path.endsWith('.exe') || f is File && f.path.endsWith('.tar.gz')) {
          final age = DateTime.now().difference(await f.lastModified());
          if (age.inHours > 1) {
            await f.delete();
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _closeAppGracefully() async {
    if (!Platform.isWindows) return;

    try {
      final currentPid = pid;
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', currentPid.toString(), '/F'],
            runInShell: true);
      }
    } catch (_) {}
  }

  Future<void> installUpdate() async {
    if (_cachedDownloadPath == null) return;

    if (_installAttempts >= _maxInstallAttempts) {
      _status = UpdateStatus.error;
      _errorMessage = 'فشل التثبيت بعد $_maxInstallAttempts محاولات';
      _errorDetail = 'يرجى تنزيل التحديث يدوياً من الموقع';
      notifyListeners();
      return;
    }

    _installAttempts++;
    _status = UpdateStatus.installing;
    notifyListeners();

    try {
      final file = File(_cachedDownloadPath!);
      if (!await file.exists()) {
        _status = UpdateStatus.error;
        _errorMessage = 'ملف التحديث غير موجود';
        _errorDetail = 'ربما تم حذفه';
        notifyListeners();
        return;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _status = UpdateStatus.error;
        _errorMessage = 'ملف التحديث تالف';
        _errorDetail = 'حجم الملف صفر';
        notifyListeners();
        return;
      }

      if (_updateInfo?.sha256 != null) {
        final hash = await _computeSha256(file);
        if (hash != _updateInfo!.sha256) {
          _status = UpdateStatus.error;
          _errorMessage = 'توقيع الملف غير متطابق';
          _errorDetail = 'تم رفض التثبيت حفاظاً على الأمان';
          notifyListeners();
          return;
        }
      }

      if (Platform.isWindows) {
        await _closeAppGracefully();

        final result = await Process.run(
          file.path,
          ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
          runInShell: true,
        ).timeout(const Duration(seconds: 30));

        if (result.exitCode != 0) {
          _status = UpdateStatus.error;
          _errorMessage = 'فشل تشغيل المثبت';
          _errorDetail = 'رمز الخطأ: ${result.exitCode}';
          notifyListeners();
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_installed_version', _updateInfo!.version);
        await prefs.remove('ignored_update_version');

        _status = UpdateStatus.restartRequired;
      } else if (Platform.isLinux) {
        final dir = await getApplicationSupportDirectory();
        final extractDir = '${dir.path}/extracted';
        final extractDirectory = Directory(extractDir);
        if (await extractDirectory.exists()) {
          await extractDirectory.delete(recursive: true);
        }
        await extractDirectory.create(recursive: true);

        final result = await Process.run(
          'tar',
          ['-xzf', file.path, '-C', extractDir],
          runInShell: true,
        ).timeout(const Duration(seconds: 30));

        if (result.exitCode != 0) {
          if (await extractDirectory.exists()) {
            await extractDirectory.delete(recursive: true);
          }
          _status = UpdateStatus.error;
          _errorMessage = 'فشل فك الضغط';
          _errorDetail = 'رمز الخطأ: ${result.exitCode}';
          notifyListeners();
          return;
        }

        final appDir = Directory(extractDir);
        final files = await appDir.list(recursive: true).toList();
        bool binaryCopied = false;
        for (final f in files) {
          if (f is File) {
            final relativePath = f.path.replaceAll('${appDir.path}/', '');
            if (relativePath == 'darsak_desktop') {
              await f.copy('/opt/darsakai/darsak_desktop');
              await Process.run('chmod', ['+x', '/opt/darsakai/darsak_desktop']);
              binaryCopied = true;
            }
          }
        }

        if (await extractDirectory.exists()) {
          await extractDirectory.delete(recursive: true);
        }

        if (!binaryCopied) {
          _status = UpdateStatus.error;
          _errorMessage = 'الملف التنفيذي غير موجود في الأرشيف';
          _errorDetail = 'قد يكون الأرشيف تالفاً';
          notifyListeners();
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_installed_version', _updateInfo!.version);
        await prefs.remove('ignored_update_version');

        _status = UpdateStatus.restartRequired;
      }

      _installAttempts = 0;
      _cachedDownloadPath = null;
    } catch (e) {
      if (e is TimeoutException) {
        _status = UpdateStatus.error;
        _errorMessage = 'انتهت مهلة التثبيت';
        _errorDetail = 'قد يكون التطبيق قيد التشغيل';
      } else {
        _status = UpdateStatus.error;
        _errorMessage = 'فشل التثبيت';
        _errorDetail = e.toString();
      }
    }

    notifyListeners();
  }

  void restartApp() {
    if (Platform.isWindows && _cachedDownloadPath != null) {
      try {
        Process.run(
          _cachedDownloadPath!,
          ['/VERYSILENT', '/SUPPRESSMSGBOXES'],
          runInShell: true,
        );
      } catch (_) {}
    }
    exit(0);
  }

  void dismiss() {
    _status = UpdateStatus.upToDate;
    _updateInfo = null;
    _errorMessage = null;
    _errorDetail = null;
    _downloadProgress = 0;
    notifyListeners();
  }

  void retry() {
    _installAttempts = 0;
    if (_errorMessage != null) {
      checkForUpdate(force: true);
    }
  }
}
