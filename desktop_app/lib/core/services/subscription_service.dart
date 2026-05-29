import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../utils/constants.dart';

final class SubscriptionService {
  final ApiClient _client;

  SubscriptionService(this._client);

  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      return await _client.get('/subscriptions/my');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> activateCode(String code) async {
    return _client.post('/subscriptions/activate', data: {'code': code});
  }

  Future<List<dynamic>> getPlans() async {
    return _client.getList('/subscriptions/plans');
  }

  Future<Map<String, dynamic>> checkVersion(String platform) async {
    return _client.get('/versions/$platform');
  }

  Future<void> cacheSubscription(Map<String, dynamic>? data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data != null) {
      await prefs.setString(PrefKeys.subscriptionData, jsonEncode(data));
    } else {
      await prefs.remove(PrefKeys.subscriptionData);
    }
  }

  Future<Map<String, dynamic>?> getCachedSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(PrefKeys.subscriptionData);
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  bool isSubscriptionActive(Map<String, dynamic>? subscription) {
    if (subscription == null) return false;
    if (subscription['is_expired'] == true) return false;
    if (subscription['is_active'] == false) return false;
    final expiryStr = subscription['expires_at']?.toString();
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null) return expiry.isAfter(DateTime.now());
    }
    return true;
  }

  int getRemainingDays(Map<String, dynamic>? subscription) {
    if (subscription == null) return 0;
    // Always calculate from expires_at to ensure real-time decrement.
    // Backend's days_remaining is stale (calculated at fetch time).
    final expiryStr = subscription['expires_at']?.toString();
    if (expiryStr == null) return 0;
    final expiry = DateTime.tryParse(expiryStr);
    if (expiry == null) return 0;
    final diff = expiry.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool isTrial(Map<String, dynamic>? subscription) {
    return subscription?['is_trial'] == true;
  }

  bool hasTrialEnded(Map<String, dynamic>? subscription) {
    if (subscription == null) return true;
    final trialEnd = subscription['trial_end_date']?.toString();
    if (trialEnd == null) return false;
    final end = DateTime.tryParse(trialEnd);
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }
}
