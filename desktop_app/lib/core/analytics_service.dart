import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import '../core/constants.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  static const String _queueKey = 'analytics_queue';
  static const int _maxQueueSize = 200;
  bool _initialized = false;
  bool _enabled = true;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('analytics_enabled') ?? true;

    if (!_enabled) return;

    if (!kDebugMode) {
      const posthogApiKey = String.fromEnvironment(
        'POSTHOG_API_KEY',
        defaultValue: '',
      );
      if (posthogApiKey.isNotEmpty) {
        try {
          await Posthog().init(
            apiKey: posthogApiKey,
            host: 'https://app.posthog.com',
            options: PosthogOptions(
              captureMode: CaptureMode.always,
              captureScreenViews: false,
              captureDeepLinks: false,
            ),
          );
        } catch (_) {}
      }
    }

    await _flushQueue();
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('analytics_enabled', enabled);
    });
  }

  void _track(String event, {Map<String, dynamic>? properties}) {
    if (!_enabled) return;
    if (kDebugMode) return;

    final props = {
      'version': AppConstants.appVersion,
      'platform': AppConstants.platformName,
      'distinct_id': AppConstants.platformName,
      if (properties != null) ...properties,
    };

    if (!kDebugMode) {
      try {
        Posthog().capture(event: event, properties: props);
      } catch (_) {}
    }

    final entry = {
      'event': event,
      'properties': props,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };

    _sendOrQueue(entry);
  }

  void _sendOrQueue(Map<String, dynamic> entry) async {
    try {
      await _dio.post('/analytics/event', data: entry);
    } catch (_) {
      await _enqueue(entry);
    }
  }

  Future<void> _enqueue(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      final queue = raw != null ? List<Map<String, dynamic>>.from(jsonDecode(raw)) : <Map<String, dynamic>>[];
      if (queue.length >= _maxQueueSize) {
        queue.removeAt(0);
      }
      queue.add(entry);
      await prefs.setString(_queueKey, jsonEncode(queue));
    } catch (_) {}
  }

  Future<void> _flushQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_queueKey);
      if (raw == null) return;
      final queue = List<Map<String, dynamic>>.from(jsonDecode(raw));
      if (queue.isEmpty) return;

      await prefs.remove(_queueKey);

      for (final entry in queue) {
        try {
          await _dio.post('/analytics/event', data: entry);
        } catch (_) {
          await _enqueue(entry);
          return;
        }
      }
    } catch (_) {}
  }

  void appOpened() => _track('app_opened');
  void loginSuccess() => _track('login_success');
  void loginFailed({String? reason}) => _track('login_failed', properties: {'reason': reason});
  void updateCheck({String? channel}) => _track('update_check', properties: {'channel': channel});
  void updateAvailable(String version, {String? channel}) => _track('update_available', properties: {'version': version, 'channel': channel});
  void updateStarted(String version) => _track('update_started', properties: {'version': version});
  void updateDownloaded(String version) => _track('update_downloaded', properties: {'version': version});
  void updateInstalled(String version) => _track('update_installed', properties: {'version': version});
  void updateFailed(String version, String error) => _track('update_failed', properties: {'version': version, 'error': error});
  void hashMismatch(String version) => _track('hash_mismatch', properties: {'version': version});
  void installerFailed(String version, String error) => _track('installer_failed', properties: {'version': version, 'error': error});
  void appRestartRequired(String version) => _track('app_restart_required', properties: {'version': version});
  void offlineModeEnabled() => _track('offline_mode_enabled');
  void reconnectSuccess() => _track('reconnect_success');
  void crashDetected(String error) => _track('crash_detected', properties: {'error': error});
}
