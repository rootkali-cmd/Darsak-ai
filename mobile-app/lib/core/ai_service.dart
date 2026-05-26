import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiService {
  static const String _apiKey = 'ydc-sk-f5e0a57bdac0f542-Wsky9guXdqGprP0Sk7FNWpH7XbN7iKxQ-5ad8efee';
  static const int _dailyLimit = 5;
  static const String _prefCount = 'ai_chat_count';
  static const String _prefDate = 'ai_chat_date';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.you.com',
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  int _remaining = _dailyLimit;

  int get remaining => _remaining;

  Future<void> loadUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_prefDate) ?? '';
    final today = DateTime.now().toIso8601String().split('T').first;
    if (savedDate != today) {
      await prefs.setInt(_prefCount, 0);
      await prefs.setString(_prefDate, today);
      _remaining = _dailyLimit;
    } else {
      final count = prefs.getInt(_prefCount) ?? 0;
      _remaining = _dailyLimit - count;
    }
  }

  Future<String> ask(String question) async {
    if (_remaining <= 0) {
      throw Exception('لقد استنفدت حد الأسئلة اليومي. ارجع غداً');
    }

    final response = await _dio.post(
      '/v1/research',
      data: {
        'input': question,
        'research_effort': 'lite',
      },
      options: Options(headers: {
        'X-API-Key': _apiKey,
        'Content-Type': 'application/json',
      }),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      final content = data['output']['content'] as String? ?? 'لم أتمكن من العثور على إجابة';

      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_prefCount) ?? 0) + 1;
      await prefs.setInt(_prefCount, count);
      _remaining = _dailyLimit - count;

      return content;
    } else {
      throw Exception('حدث خطأ في الاتصال، حاول مرة أخرى');
    }
  }
}
