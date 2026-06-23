import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class AiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  int _remaining = AppConstants.aiDailyLimit;

  AiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.storageKeyToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  int get remaining => _remaining;

  Future<void> loadUsage() async {
    try {
      final response = await _dio.get('/students/me/ai-usage');
      if (response.statusCode == 200) {
        _remaining = response.data['remaining'] as int? ?? _remaining;
      }
    } catch (_) {
      // Keep default if fetch fails
    }
  }

  Future<Map<String, dynamic>> ask(String question, {String? conversationId}) async {
    if (_remaining <= 0) {
      throw Exception('لقد استنفدت حد الأسئلة اليومي. ارجع غداً');
    }

    final response = await _dio.post(
      '/students/me/ai-chat',
      data: {
        'question': question,
        if (conversationId != null) 'conversation_id': conversationId,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      _remaining = data['remaining'] as int? ?? _remaining - 1;
      return {
        'answer': data['answer'] as String? ?? 'لم أتمكن من العثور على إجابة',
        'conversation_id': data['conversation_id'] as String? ?? '',
      };
    } else {
      throw Exception('حدث خطأ في الاتصال، حاول مرة أخرى');
    }
  }
}
