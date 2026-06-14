import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import 'analytics_service.dart';
import 'structured_logger.dart';

class AndroidUpdateInfo {
  final String version;
  final int build;
  final bool mandatory;
  final List<String> changelog;
  final List<String> changelogEn;
  final String? downloadUrl;
  final int? sizeMb;
  final String? releaseDate;

  AndroidUpdateInfo({
    required this.version,
    required this.build,
    required this.mandatory,
    required this.changelog,
    required this.changelogEn,
    this.downloadUrl,
    this.sizeMb,
    this.releaseDate,
  });

  factory AndroidUpdateInfo.fromJson(Map<String, dynamic> json) {
    final raw = json['changelog'];
    final rawEn = json['changelog_en'];
    return AndroidUpdateInfo(
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

enum AndroidUpdateStatus {
  idle,
  checking,
  available,
  error,
}

class AndroidUpdateService extends ChangeNotifier {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
  ));

  AndroidUpdateStatus _status = AndroidUpdateStatus.idle;
  AndroidUpdateInfo? _updateInfo;
  String? _errorMessage;

  AndroidUpdateStatus get status => _status;
  AndroidUpdateInfo? get updateInfo => _updateInfo;
  String? get errorMessage => _errorMessage;
  bool get isChecking => _status == AndroidUpdateStatus.checking;
  bool get hasUpdate => _status == AndroidUpdateStatus.available;

  static bool _isNewerVersion(String latest, String current) {
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

  Future<void> checkForUpdate() async {
    if (_status == AndroidUpdateStatus.checking) return;

    _status = AndroidUpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _dio.get('/versions/android');
      if (response.statusCode != 200) {
        _status = AndroidUpdateStatus.idle;
        notifyListeners();
        return;
      }

      final data = response.data as Map<String, dynamic>;
      final latest = AndroidUpdateInfo.fromJson(data);

      if (!latest.isValid) {
        _status = AndroidUpdateStatus.idle;
        notifyListeners();
        return;
      }

      final currentVersion = AppConstants.appVersion;
      if (_isNewerVersion(latest.version, currentVersion)) {
        _updateInfo = latest;
        _status = AndroidUpdateStatus.available;
        AnalyticsService.instance.updateAvailable(latest.version);
        StructuredLogger.instance.info('update_available', data: {
          'version': latest.version,
          'current': currentVersion,
        });
      } else {
        _status = AndroidUpdateStatus.idle;
      }
    } catch (_) {
      _status = AndroidUpdateStatus.idle;
    }

    notifyListeners();
  }

  Future<void> openDownloadPage() async {
    if (_updateInfo?.downloadUrl == null) return;
    final uri = Uri.parse(_updateInfo!.downloadUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void dismiss() {
    _status = AndroidUpdateStatus.idle;
    _updateInfo = null;
    _errorMessage = null;
    notifyListeners();
  }
}
