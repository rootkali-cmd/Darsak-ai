import 'package:dio/dio.dart';
import '../utils/logger.dart';

final class TelegramService {
  static const String _botToken = 'YOUR_BOT_TOKEN_HERE';
  static const String _chatId = 'YOUR_CHAT_ID_HERE';
  static final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  /// Notify admin channel about a new payment request.
  static Future<bool> sendPaymentNotification({
    required String planName,
    required String planPrice,
    required String paymentMethod,
    required String senderInfo,
    required String? receiptFileName,
  }) async {
    if (_botToken.contains('YOUR_BOT')) {
      AppLogger.instance.info('telegram_skipped: token not configured');
      return false;
    }

    final message = '''
🛎️ طلب دفع جديد - DarsakAI

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
    } catch (e) {
      AppLogger.instance.warning('telegram_send_failed', error: e);
      return false;
    }
  }
}
