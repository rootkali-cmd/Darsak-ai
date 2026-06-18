import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

/// Top-level handler for background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 [BG Teacher] Received: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;
  bool _isInitialized = false;

  static const _channelId = 'darsak_teacher_push_channel';
  static const _channelName = 'DarsakAI Teacher Notifications';
  static const _tokenKey = 'fcm_token';
  static const _baseUrl = 'https://darsak-backend.fly.dev/api';

  /// Initialize Firebase + FCM
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
    );
    debugPrint('📱 [Teacher] FCM Permission: ${settings.authorizationStatus}');

    // Create notification channel
    await _createNotificationChannel();

    // Initialize local notifications
    await _initLocalNotifications();

    // Get initial token
    _currentToken = await _fcm.getToken();
    debugPrint('📱 [Teacher] FCM Token: ${_currentToken?.substring(0, 20)}...');

    if (_currentToken != null) {
      await _saveToken(_currentToken!);
      await _uploadToken(_currentToken!);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('📱 [Teacher] FCM Token Refreshed');
      _currentToken = newToken;
      _saveToken(newToken);
      _uploadToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check killed state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 [Teacher] App opened from killed state');
      Future.delayed(const Duration(seconds: 2), () {
        _handleNotificationTap(initialMessage);
      });
    }

    _isInitialized = true;
  }

  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'إشعارات DarsakAI للمعلمين',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );
      }
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('📱 [Teacher] Local notification tapped');
      },
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 [Teacher] [FG] Received: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    final id = message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch;

    _localNotifications.show(
      id,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'إشعارات DarsakAI للمعلمين',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            notification.body ?? '',
            contentTitle: notification.title,
          ),
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📱 [Teacher] Notification tapped: ${message.data}');

    final type = message.data['type'] ?? '';
    final data = message.data;

    _storePendingNavigation(type, data);
  }

  Future<void> _storePendingNavigation(String type, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification_type', type);
    await prefs.setString('pending_notification_data', jsonEncode(data));
  }

  Future<String?> getToken() async {
    _currentToken ??= await _fcm.getToken();
    return _currentToken;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _uploadToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null || accessToken.isEmpty) return;

      final response = await http.post(
        Uri.parse('$_baseUrl/teachers/fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fcm_token': token,
          'platform': 'android',
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('📱 [Teacher] FCM Token uploaded successfully');
      } else {
        debugPrint('📱 [Teacher] FCM Token upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📱 [Teacher] FCM Token upload error: $e');
    }
  }
}
