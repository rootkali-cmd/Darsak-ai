import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';

class WatchClock {
  int _secondsWatched = 0;
  int _lastTick = 0;
  DateTime? _startTime;

  void start() {
    _startTime = DateTime.now();
    _lastTick = DateTime.now().millisecondsSinceEpoch;
  }

  void tick() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastTick > 0 && now - _lastTick < 2000) {
      _secondsWatched += ((now - _lastTick) / 1000).round();
    }
    _lastTick = now;
  }

  void stop() => tick();

  int get maxWatchedDuration => _secondsWatched;
}

class AnalyticsTrackingService {
  static const _throttleIntervalSeconds = 300; // 5 minutes
  static int _lastUploadTime = 0;
  static Timer? _periodicTimer;
  static final WatchClock _clock = WatchClock();

  static void startTracking(String videoId, {int initialPosition = 0}) {
    _clock.start();
    _lastUploadTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _periodicTimer = Timer.periodic(
      const Duration(seconds: _throttleIntervalSeconds),
      (_) => _shouldUpload(videoId),
    );
  }

  static void stopTracking(String videoId, {
    int position = 0,
    double speed = 1.0,
    bool isCompleted = false,
    String eventType = 'exit',
  }) {
    _clock.stop();
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _uploadAnalytics(
      videoId: videoId,
      position: position,
      speed: speed,
      isCompleted: isCompleted,
      eventType: eventType,
    );
  }

  static Future<void> _shouldUpload(String videoId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - _lastUploadTime >= _throttleIntervalSeconds) {
      _clock.tick();
      await _uploadAnalytics(
        videoId: videoId,
        position: 0,
        speed: 1.0,
        isCompleted: false,
        eventType: 'periodic_5min',
      );
      _lastUploadTime = now;
    }
  }

  static Future<void> onPause(String videoId, int position, double speed) {
    _clock.tick();
    return _uploadAnalytics(
      videoId: videoId,
      position: position,
      speed: speed,
      isCompleted: false,
      eventType: 'pause',
    );
  }

  static Future<void> onSeek(String videoId, int position, double speed) {
    _clock.tick();
    return _uploadAnalytics(
      videoId: videoId,
      position: position,
      speed: speed,
      isCompleted: false,
      eventType: 'seek',
    );
  }

  static Future<void> _uploadAnalytics({
    required String videoId,
    required int position,
    required double speed,
    required bool isCompleted,
    required String eventType,
  }) async {
    try {
      final api = ApiService();
      await api.dio.post(
        '/video-analytics/track?video_id=$videoId',
        data: {
          'last_position': position,
          'max_watched_duration': _clock.maxWatchedDuration,
          'current_speed': speed,
          'is_completed': isCompleted,
          'last_event_type': eventType,
        },
      );
    } catch (_) {}
  }
}
