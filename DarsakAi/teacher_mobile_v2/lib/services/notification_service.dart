import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const _channelId = 'darsak_subscriptions_channel';
  static const _channelName = 'Darsak Subscriptions';

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId, _channelName,
          description: 'إشعارات الاشتراكات',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }
    _isInitialized = true;
  }

  Future<void> showSubscriptionActivated({String planName = '', String period = ''}) async {
    if (!_isInitialized) return;
    final id = DateTime.now().millisecondsSinceEpoch % 2147483647;
    await _plugin.show(
      id,
      '✅ تم تفعيل اشتراكك بنجاح',
      planName.isNotEmpty ? 'باقة $planName ($period) مفعلة الآن' : 'تم تفعيل اشتراكك بنجاح',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: 'إشعارات الاشتراكات',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(
            'تم تفعيل اشتراكك بنجاح',
            contentTitle: '✅ تم تفعيل اشتراكك بنجاح',
          ),
        ),
      ),
    );
  }
}
