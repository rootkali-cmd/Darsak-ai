import 'package:telephony/telephony.dart';
import 'notification_service.dart';

class SmsListenerService {
  static final Telephony _telephony = Telephony.instance;

  static Future<void> startListening() async {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        _processSms(message.body ?? '', message.address ?? '');
      },
      onBackgroundMessage: _backgroundHandler,
      listenInBackground: true,
    );
  }

  static Future<void> _processSms(String body, String sender) async {
    final vodafoneRegex = RegExp(
      r'Vodafone Cash.*?(\d{11}).*?(\d+\.?\d*)\s?(EGP|LE|ج\.م)',
    );
    final match = vodafoneRegex.firstMatch(body);
    if (match != null) {
      final phone = match.group(1);
      final amount = match.group(2);
      if (phone != null && amount != null) {
        await NotificationService.showPaymentAlert(phone, amount);
        // TODO: Check against pending transactions on server
      }
    }
  }

  static Future<void> _backgroundHandler(SmsMessage message) async {
    _processSms(message.body ?? '', message.address ?? '');
  }
}
