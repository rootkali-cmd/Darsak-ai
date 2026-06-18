import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../services/notification_service.dart';

/// Top-level handler for background messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📱 [BG] Received: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  String? _currentToken;
  bool _isInitialized = false;

  static const _channelId = 'darsak_push_channel';
  static const _channelName = 'DarsakAI Notifications';
  static const _tokenKey = 'fcm_token';

  /// Initialize Firebase + FCM
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+)
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: false,
    );
    debugPrint('📱 FCM Permission: ${settings.authorizationStatus}');

    // Create notification channel
    await _createNotificationChannel();

    // Initialize local notifications for foreground display
    await _initLocalNotifications();

    // Get initial token
    _currentToken = await _fcm.getToken();
    debugPrint('📱 FCM Token: ${_currentToken?.substring(0, 20)}...');

    // Save token locally
    if (_currentToken != null) {
      await _saveToken(_currentToken!);
      await _uploadToken(_currentToken!);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('📱 FCM Token Refreshed: ${newToken.substring(0, 20)}...');
      _currentToken = newToken;
      _saveToken(newToken);
      _uploadToken(newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app opened from notification (killed state)
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📱 App opened from killed state via notification');
      // Delay slightly to let app initialize
      Future.delayed(const Duration(seconds: 2), () {
        _handleNotificationTap(initialMessage);
      });
    }

    _isInitialized = true;
  }

  /// Create Android notification channel
  Future<void> _createNotificationChannel() async {
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'إشعارات DarsakAI',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );
      }
    }
  }

  /// Initialize local notifications for foreground display
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('📱 Local notification tapped: ${details.payload}');
      },
    );
  }

  /// Handle foreground messages — show as local notification
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 [FG] Received: ${message.notification?.title}');

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
          channelDescription: 'إشعارات DarsakAI',
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

    // Update badge count
    _incrementBadge();
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📱 Notification tapped: ${message.data}');

    final type = message.data['type'] ?? '';
    final data = message.data;

    // Navigate based on notification type
    // The app's main.dart will handle navigation via navigatorKey
    // For now, we store the pending navigation
    _storePendingNavigation(type, data);
  }

  /// Store pending navigation for app to pick up
  Future<void> _storePendingNavigation(String type, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_notification_type', type);
    await prefs.setString('pending_notification_data', jsonEncode(data));
  }

  /// Get stored FCM token
  Future<String?> getToken() async {
    _currentToken ??= await _fcm.getToken();
    return _currentToken;
  }

  /// Save token to local storage
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Upload token to backend
  Future<void> _uploadToken(String token) async {
    try {
      final tokenParts = token.split('.');
      if (tokenParts.length < 2) return;

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString(AppConstants.storageKeyToken);
      if (accessToken == null || accessToken.isEmpty) return;

      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/students/me/fcm-token'),
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
        debugPrint('📱 FCM Token uploaded successfully');
      } else {
        debugPrint('📱 FCM Token upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('📱 FCM Token upload error: $e');
    }
  }

  /// Increment notification badge
  Future<void> _incrementBadge() async {
    // Badge is managed by the app's notification count
  }

  /// Subscribe to topic (optional)
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  /// Unsubscribe from topic (optional)
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }
}
