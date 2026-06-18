import 'dart:async';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Timer? _backgroundTimer;
  bool _isInitialized = false;

  static const _channelId = 'darsak_exams_channel';
  static const _channelName = 'Darsak Exams';
  static const _channelDesc = 'Notifications for exam reminders and new exams';
  static const _lastCheckKey = 'last_exam_check_timestamp';
  static const _scheduledDeadlinesKey = 'scheduled_deadline_ids';

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDesc,
            importance: Importance.high,
            sound: RawResourceAndroidNotificationSound('notification_sound'),
            enableVibration: true,
          ),
        );
      }
    }

    _isInitialized = true;
  }

  Future<void> scheduleDeadlineReminder({
    required String examId,
    required String examTitle,
    required DateTime deadlineAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final scheduledIds = prefs.getStringList(_scheduledDeadlinesKey) ?? [];
    if (scheduledIds.contains(examId)) return;

    final reminderTime = deadlineAt.subtract(const Duration(hours: 4));
    if (reminderTime.isBefore(DateTime.now())) return;

    final tzDeadline = tz.TZDateTime.from(reminderTime, tz.local);
    final id = examId.hashCode.abs() % 2147483647;

    await _plugin.zonedSchedule(
      id,
      'تذكير: امتحان قريب',
      'الامتحان "$examTitle" ينتهي خلال 4 ساعات. استعد الآن!',
      tzDeadline,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    scheduledIds.add(examId);
    await prefs.setStringList(_scheduledDeadlinesKey, scheduledIds);
  }

  Future<void> showNewExamNotification({
    required String examId,
    required String examTitle,
    String? description,
  }) async {
    final id = (examId.hashCode.abs() % 2147483647) + 1000;

      await _plugin.show(
      id,
      'اختبار جديد متاح',
      description?.isNotEmpty == true
          ? '$examTitle - $description'
          : '$examTitle متاح الآن. ادخل لحله!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
          styleInformation: BigTextStyleInformation(
            description?.isNotEmpty == true
                ? '$examTitle - $description'
                : '$examTitle متاح الآن. ادخل لحله!',
            contentTitle: 'اختبار جديد متاح',
          ),
        ),
      ),
    );
  }

  void startPeriodicCheck({
    required String studentId,
    required Future<List<dynamic>> Function(String studentId, String lastCheck) checkNewExams,
    required void Function(List<dynamic> newExams) onNewExams,
  }) {
    _backgroundTimer?.cancel();

    _backgroundTimer = Timer.periodic(const Duration(minutes: 30), (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getString(_lastCheckKey) ?? DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

        final newExams = await checkNewExams(studentId, lastCheck);

        await prefs.setString(_lastCheckKey, DateTime.now().toIso8601String());

        if (newExams.isNotEmpty) {
          onNewExams(newExams);
          for (final exam in newExams) {
            final examId = exam['id'] ?? '';
            final title = exam['title'] ?? 'اختبار جديد';
            final desc = exam['description'];

            await showNewExamNotification(examId: examId, examTitle: title, description: desc);

            final deadlineStr = exam['deadline_at'];
            if (deadlineStr != null) {
              try {
                final deadline = DateTime.parse(deadlineStr.toString().replaceFirst('Z', '+00:00'));
                await scheduleDeadlineReminder(examId: examId, examTitle: title, deadlineAt: deadline);
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    });
  }

  void stopPeriodicCheck() {
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduledDeadlinesKey);
    await prefs.remove(_lastCheckKey);
  }
}
