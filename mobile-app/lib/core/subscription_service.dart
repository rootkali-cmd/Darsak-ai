import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class SubscriptionService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  SubscriptionService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
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

  Future<Map<String, dynamic>> getMySubscription() async {
    final response = await _dio.get('/subscriptions/my');
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    await _cacheSubscription(data);
    return data;
  }

  Future<Map<String, dynamic>> activateCode(String code) async {
    final response = await _dio.post('/subscriptions/activate', data: {
      'code': code,
    });
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
    await _cacheSubscription(data);
    return data;
  }

  Future<Map<String, dynamic>> checkVersion() async {
    final response = await _dio.get('/versions/mobile');
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<void> _cacheSubscription(Map<String, dynamic> data) async {
    await _storage.write(
      key: AppConstants.storageKeySubscription,
      value: jsonEncode(data),
    );
  }

  Future<Map<String, dynamic>?> getCachedSubscription() async {
    final raw = await _storage.read(key: AppConstants.storageKeySubscription);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<bool> isSubscriptionActive() async {
    final data = await getCachedSubscription();
    if (data == null) return false;
    final status = data['status'] as String?;
    if (status != 'active') return false;
    final expiresAt = data['expires_at'] as String?;
    if (expiresAt == null) return false;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return false;
    return expiry.isAfter(DateTime.now());
  }

  Future<int> getRemainingDays() async {
    final data = await getCachedSubscription();
    if (data == null) return 0;
    final expiresAt = data['expires_at'] as String?;
    if (expiresAt == null) return 0;
    final expiry = DateTime.tryParse(expiresAt);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays;
  }

  Future<void> clearCache() async {
    await _storage.delete(key: AppConstants.storageKeySubscription);
  }

  Future<Map<String, dynamic>> sendPaymentRequest(String planId, String phoneNumber, int amount, String? screenshot) async {
    final data = {
      'plan_id': planId,
      'phone_number': phoneNumber,
      'amount': amount,
      if (screenshot != null) 'screenshot': screenshot,
    };
    final response = await _dio.post('/subscriptions/payment-request', data: data);
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await _dio.get('/subscriptions/notifications');
    return response.data is List ? response.data as List : [];
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.post('/subscriptions/notifications/$notificationId/read');
  }
}
