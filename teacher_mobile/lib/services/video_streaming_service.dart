import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';

class VideoStreamingService {
  static Future<Map<String, dynamic>> getStreamUrl(String lessonId) async {
    final api = ApiService();
    final response = await api.dio.get('/lessons/$lessonId/stream-url/');
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid stream URL response');
  }

  static Future<Map<String, dynamic>> getStudentAnalytics(String videoId) async {
    final api = ApiService();
    final response = await api.dio.get('/video-analytics/my/$videoId/');
    final data = response.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid analytics response');
  }

  static Future<Map<String, dynamic>> resumeState(String videoId) async {
    try {
      final result = await getStudentAnalytics(videoId);
      return {
        'last_position': result['last_position'] ?? 0,
        'current_speed': result['current_speed'] ?? 1.0,
        'max_watched_duration': result['max_watched_duration'] ?? 0,
      };
    } catch (_) {
      return {'last_position': 0, 'current_speed': 1.0, 'max_watched_duration': 0};
    }
  }
}
