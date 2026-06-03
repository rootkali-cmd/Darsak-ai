import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == 'approve') {
          // TODO: Call API to approve transaction
        } else if (response.actionId == 'reject') {
          // TODO: Call API to reject transaction
        }
      },
    );
  }

  static Future<void> showPaymentAlert(String phone, String amount) async {
    await _plugin.show(
      1,
      'دفعة جديدة',
      'تم استلام $amount ج.م من $phone',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payments',
          'المدفوعات',
          importance: Importance.high,
          priority: Priority.high,
          actions: [
            AndroidNotificationAction(
              'approve',
              'موافقة',
              showsUserInterface: true,
            ),
            AndroidNotificationAction(
              'reject',
              'رفض',
              showsUserInterface: true,
            ),
          ],
        ),
      ),
    );
  }
}
