import 'package:dio/dio.dart';
import '../core/constants.dart';

class TelemetryService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  void _send(String event, {String? version, String? error}) {
    try {
      _dio.post('/telemetry/event', data: {
        'event': event,
        'version': version ?? AppConstants.appVersion,
        'platform': AppConstants.platformName,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        if (error != null) 'error': error,
      });
    } catch (_) {}
  }

  void updateCheck() => _send('update_check');
  void updateAvailable(String version) => _send('update_available', version: version);
  void updateStarted(String version) => _send('update_started', version: version);
  void updateDownloaded(String version) => _send('update_downloaded', version: version);
  void updateInstalled(String version) => _send('update_installed', version: version);
  void updateFailed(String version, String error) => _send('update_failed', version: version, error: error);
  void hashMismatch(String version, String error) => _send('hash_mismatch', version: version, error: error);
  void installerFailed(String version, String error) => _send('installer_failed', version: version, error: error);
  void restartRequired(String version) => _send('app_restart_required', version: version);
}
