import 'dart:convert';
import 'package:dio/dio.dart';

class AiService {
  late final Dio _dio;
  int _remaining = 100;

  static const _apiKey = 'fw_RrDhD6TuaHTUt9mznWZ5kr';
  static const _baseUrl = 'https://api.fireworks.ai/inference/v1';
  static const _model = 'accounts/fireworks/models/deepseek-v4-flash';

  static const _systemPrompt =
      'أنت مساعد تعليمي ذكي اسمك "دَرسك AI". تابع لمنصة DarsakAI التعليمية. '
      'مهمتك الأساسية: مساعدة الطلاب في الدراسة والمناهج التعليمية المصرية فقط. '
      'قواعد أمان صارمة: '
      '- أنت ملتزم بالتعليم فقط. أي سؤال عن أسلحة، قنابل، مخدرات، عنف، اختراق، أو أي محتوى ضار - ارفض الرد فوراً '
      '- ركز فقط على المناهج التعليمية: الرياضيات، العلوم، اللغة العربية، الإنجليزية، الدراسات الاجتماعية '
      'قدرات خاصة: '
      '- يمكنك البحث والتفكير المنطقي لحل المسائل '
      '- إذا طلب الطالب إنشاء اختبار، قم بتوليد أسئلة متنوعة مع الإجابات '
      '- قدم تفسيرات مبسطة ومناسبة لعمر الطالب '
      'شكل الرد: '
      '- أجب بالعربية بشكل واضح ومفصل '
      '- استخدم تنسيق Markdown: **نص عريض**، *مائل*، `كود`، - نقاط، # عناوين '
      '- إذا كنت تفكر، ابدأ بعبارة "🤔 تفكير:" '
      '- إذا قمت بإنشاء كويز، ابدأ بعبارة "📝 كويز:"';

  AiService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
    ));
  }

  int get remaining => _remaining;

  Future<void> loadUsage() async {}

  Future<String> ask(String question, {List<Map<String, String>>? history}) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt},
    ];

    if (history != null) {
      messages.addAll(history);
    }

    messages.add({'role': 'user', 'content': question});

    final response = await _dio.post(
      '/chat/completions',
      data: {
        'model': _model,
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 2048,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data;
      return data['choices'][0]['message']['content'] as String? ??
          'لم أتمكن من العثور على إجابة';
    } else {
      throw Exception('حدث خطأ في الاتصال، حاول مرة أخرى');
    }
  }
}
