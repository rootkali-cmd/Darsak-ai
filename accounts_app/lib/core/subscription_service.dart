import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String _baseUrl = 'https://darsak-ai-o8cs.vercel.app/api';
  static const String _cacheKey = 'cached_subscription';

  late final Dio _dio;
  final SharedPreferences _prefs;

  SubscriptionService(this._prefs) {
    _dio = Dio(BaseOptions(baseUrl: _baseUrl));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      final response = await _dio.get('/subscriptions/my');
      final data = response.data as Map<String, dynamic>;
      await _prefs.setString(_cacheKey, jsonEncode(data));
      return data;
    } catch (_) {
      final cached = _prefs.getString(_cacheKey);
      if (cached != null) {
        return jsonDecode(cached) as Map<String, dynamic>;
      }
      return null;
    }
  }

  Future<Map<String, dynamic>> activateCode(String code) async {
    final response = await _dio.post(
      '/subscriptions/activate',
      data: {'code': code},
    );
    final data = response.data as Map<String, dynamic>;
    await _prefs.setString(_cacheKey, jsonEncode(data));
    return data;
  }

  bool isSubscriptionActive(Map<String, dynamic>? subscription) {
    if (subscription == null) return false;
    final status = subscription['status'] as String?;
    final expiresAt = subscription['expires_at'] as String?;
    if (status == 'active' || status == 'trial') {
      if (expiresAt != null) {
        final expiry = DateTime.parse(expiresAt);
        if (expiry.isAfter(DateTime.now())) return true;
      }
    }
    return false;
  }

  String? getExpiryDate(Map<String, dynamic>? subscription) {
    if (subscription == null) return null;
    return subscription['expires_at'] as String?;
  }

  String? getPlanName(Map<String, dynamic>? subscription) {
    if (subscription == null) return null;
    return subscription['plan'] as String?;
  }

  String? getStatus(Map<String, dynamic>? subscription) {
    if (subscription == null) return null;
    return subscription['status'] as String?;
  }

  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
  }
}
