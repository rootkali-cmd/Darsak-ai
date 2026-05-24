import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SubscriptionService {
  late final Dio _dio;

  SubscriptionService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');
          if (refreshToken != null) {
            try {
              final response = await _dio.post('/auth/refresh',
                  data: {'refresh_token': refreshToken});
              final newToken = response.data['access_token'];
              final newRefresh = response.data['refresh_token'];
              await prefs.setString('access_token', newToken);
              await prefs.setString('refresh_token', newRefresh);
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retry = await _dio.fetch(error.requestOptions);
              handler.resolve(retry);
              return;
            } catch (_) {}
          }
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
        }
        handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      final response = await _dio.get('/subscriptions/my');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> activateCode(String code) async {
    final response = await _dio.post('/subscriptions/activate', data: {
      'code': code,
    });
    return response.data;
  }

  Future<List<dynamic>> getPlans() async {
    final response = await _dio.get('/subscriptions/plans');
    return response.data;
  }

  Future<Map<String, dynamic>> checkVersion(String platform) async {
    final response = await _dio.get('/versions/$platform');
    return response.data;
  }

  Future<void> cacheSubscription(Map<String, dynamic>? data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data != null) {
      await prefs.setString('subscription_data', jsonEncode(data));
    } else {
      await prefs.remove('subscription_data');
    }
  }

  Future<Map<String, dynamic>?> getCachedSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('subscription_data');
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  bool isSubscriptionActive(Map<String, dynamic>? subscription) {
    if (subscription == null) return false;
    // Use backend-calculated fields first
    if (subscription.containsKey('is_expired')) {
      return subscription['is_expired'] != true;
    }
    final status = subscription['status']?.toString().toLowerCase();
    if (status != null && status != 'active') return false;
    final expiryStr = subscription['expires_at']?.toString();
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null) {
        return expiry.isAfter(DateTime.now());
      }
    }
    return true;
  }

  int getRemainingDays(Map<String, dynamic>? subscription) {
    if (subscription == null) return 0;
    // Use backend-calculated field first
    if (subscription.containsKey('days_remaining')) {
      return subscription['days_remaining'] as int;
    }
    final expiryStr = subscription['expires_at']?.toString();
    if (expiryStr == null) return 0;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return 0;
    return expiry.difference(DateTime.now()).inDays;
  }
}
