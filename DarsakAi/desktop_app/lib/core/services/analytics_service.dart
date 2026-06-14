import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../utils/constants.dart';

final class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService _instance = AnalyticsService._();
  static AnalyticsService get instance => _instance;

  final ApiClient _client = ApiClient();
  bool _initialized = false;
  bool _enabled = true;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(PrefKeys.analyticsEnabled) ?? true;
    if (!_enabled) return;
    await _flushQueue();
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    SharedPreferences.getInstance().then(
        (prefs) => prefs.setBool(PrefKeys.analyticsEnabled, enabled));
  }

  void _track(String event, {Map<String, dynamic>? properties}) {
    if (!_enabled || kDebugMode) return;
    final entry = {
      'event': event,
      'properties': {
        'version': AppConstants.appVersion,
        'platform': AppConstants.platformName,
        if (properties != null) ...properties,
      },
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    _sendOrQueue(entry);
  }

  void _sendOrQueue(Map<String, dynamic> entry) async {
    try {
      await _client.post('/analytics/event', data: entry);
    } catch (_) {
      await _enqueue(entry);
    }
  }

  Future<void> _enqueue(Map<String, dynamic> entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('analytics_queue');
      final queue = raw != null
          ? List<Map<String, dynamic>>.from(jsonDecode(raw))
          : <Map<String, dynamic>>[];
      if (queue.length >= AppConstants.analyticsMaxQueueSize) queue.removeAt(0);
      queue.add(entry);
      await prefs.setString('analytics_queue', jsonEncode(queue));
    } catch (_) {}
  }

  Future<void> _flushQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('analytics_queue');
      if (raw == null) return;
      final queue = List<Map<String, dynamic>>.from(jsonDecode(raw));
      if (queue.isEmpty) return;
      await prefs.remove('analytics_queue');
      for (final entry in queue) {
        try {
          await _client.post('/analytics/event', data: entry);
        } catch (_) {
          await _enqueue(entry);
          return;
        }
      }
    } catch (_) {}
  }

  void appOpened() => _track('app_opened');
  void loginSuccess() => _track('login_success');
  void loginFailed({String? reason}) =>
      _track('login_failed', properties: {'reason': reason});
  void syncSuccess() => _track('sync_success');
  void syncFailed({String? error}) =>
      _track('sync_failed', properties: {'error': error});
}
