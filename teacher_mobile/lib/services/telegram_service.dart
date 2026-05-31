import 'package:dio/dio.dart';

final class TelegramService {
  static const String _botToken = 'YOUR_BOT_TOKEN_HERE';
  static const String _chatId = 'YOUR_CHAT_ID_HERE';
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  static Future<bool> sendPaymentNotification({
    required String planName,
    required String planPrice,
    required String paymentMethod,
    required String senderInfo,
    String? receiptFileName,
  }) async {
    if (_botToken.contains('YOUR_BOT')) return false;

    final message = '''
🛎️ طلب دفع جديد - DarsakAI Teacher

📦 الباقة: $planName
💰 السعر: $planPrice
💳 الطريقة: $paymentMethod
👤 المرسل: $senderInfo
📎 إيصال: ${receiptFileName ?? '---'}
'''.trim();

    try {
      final response = await _dio.post(
        'https://api.telegram.org/bot$_botToken/sendMessage',
        data: {
          'chat_id': _chatId,
          'text': message,
          'parse_mode': 'HTML',
        },
      );
      return response.statusCode == 200 && response.data?['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
