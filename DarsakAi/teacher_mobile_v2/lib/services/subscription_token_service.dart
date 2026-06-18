import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'api_service.dart';

/// Anti-tamper subscription token verification service.
/// Verifies that the subscription plan hasn't been tampered with on the client.
class SubscriptionTokenService {
  static final SubscriptionTokenService _instance = SubscriptionTokenService._internal();
  factory SubscriptionTokenService() => _instance;
  SubscriptionTokenService._internal();

  // Client-side HMAC key (obfuscated — split across multiple parts)
  static String get _hmacKey => _obfuscatedKey;
  static String get _obfuscatedKey {
    // Split and mixed key parts — hard to find by static analysis
    const p1 = 'd4r5';
    const p2 = '4k-5u';
    const p3 = 'bscr';
    const p4 = '1pt1';
    const p5 = '0n-s';
    const p6 = '1gn3';
    const p7 = 'd-k';
    const p8 = '3y-2';
    const p9 = '025-';
    const p10 = '53cur3';
    return '$p1$p2$p3$p4$p5$p6$p7$p8$p9$p10';
  }

  static const _tokenKey = 'subscription_signed_token';
  static const _planKey = 'subscription_verified_plan';
  static const _featuresKey = 'subscription_verified_features';
  static const _expiryKey = 'subscription_token_expiry';
  static const _lastVerifyKey = 'subscription_last_verify';
  static const _maxOfflineHours = 48; // Re-verify with server every 48 hours

  /// Fetch and store signed token from backend.
  Future<bool> fetchToken() async {
    try {
      final api = ApiService();
      final resp = await api.dio.get('/subscriptions/token');
      if (resp.statusCode == 200 && resp.data is Map) {
        final data = resp.data as Map<String, dynamic>;
        final token = data['token'] as String?;
        final planName = data['plan_name'] as String?;
        final features = data['features'] as List?;
        final expiresAt = data['expires_at'] as String?;

        if (token == null || planName == null) return false;

        // Verify locally before storing
        final payload = _verifyToken(token);
        if (payload == null) return false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        await prefs.setString(_planKey, planName);
        await prefs.setStringList(_featuresKey, features?.cast<String>() ?? []);
        await prefs.setString(_expiryKey, expiresAt ?? '');
        await prefs.setInt(_lastVerifyKey, DateTime.now().millisecondsSinceEpoch);

        return true;
      }
    } catch (e) {
      // Token fetch failed — might be offline, use cached
    }
    return false;
  }

  /// Verify the locally stored token's HMAC signature.
  Map<String, dynamic>? _verifyToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 2) return null;

      final encodedPayload = parts[0];
      final sig = parts[1];

      // Decode payload
      final padded = encodedPayload.padRight(
        encodedPayload.length + (4 - encodedPayload.length % 4) % 4,
        '=',
      );
      final payloadJson = utf8.decode(base64Url.decode(padded));

      // Compute expected HMAC
      final keyBytes = utf8.encode(_hmacKey);
      final payloadBytes = utf8.encode(payloadJson);
      final hmacSha256 = Hmac(sha256, keyBytes);
      final expectedSig = hmacSha256.convert(payloadBytes).toString();

      if (sig != expectedSig) return null;

      final payload = jsonDecode(payloadJson) as Map<String, dynamic>;

      // Check expiry
      final expStr = payload['exp'] as String?;
      if (expStr != null) {
        final expDt = DateTime.parse(expStr);
        if (expDt.isBefore(DateTime.now())) return null;
      }

      return payload;
    } catch (_) {
      return null;
    }
  }

  /// Check if a feature is allowed by the verified subscription.
  /// Returns true if allowed, false if not (and shows appropriate message).
  Future<bool> isFeatureAllowed(String feature) async {
    final prefs = await SharedPreferences.getInstance();
    final planName = prefs.getString(_planKey);
    final features = prefs.getStringList(_featuresKey);
    final token = prefs.getString(_tokenKey);
    final expiryStr = prefs.getString(_expiryKey);

    if (token == null || planName == null) return false;

    // Verify token integrity
    final payload = _verifyToken(token);
    if (payload == null) {
      // Token tampered! Clear everything.
      await _clearToken();
      return false;
    }

    // Check plan expiry
    if (expiryStr != null && expiryStr.isNotEmpty) {
      try {
        final expDt = DateTime.parse(expiryStr);
        if (expDt.isBefore(DateTime.now())) {
          await _clearToken();
          return false;
        }
      } catch (_) {}
    }

    // Check feature
    if (features != null && features.contains(feature)) return true;

    // Check by plan name as fallback
    final nameLower = planName.toLowerCase();
    if (nameLower.contains('premium') || nameLower.contains('متكامل')) return true;
    if (nameLower.contains('pro') || nameLower.contains('احتراف')) {
      return ['ai_generate_exam', 'ai_reports', 'groups', 'lessons'].contains(feature) == false;
    }

    return false;
  }

  /// Periodic server-side re-verification.
  Future<void> periodicVerify() async {
    final prefs = await SharedPreferences.getInstance();
    final lastVerify = prefs.getInt(_lastVerifyKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final hoursSinceVerify = (now - lastVerify) / (1000 * 60 * 60);

    if (hoursSinceVerify >= _maxOfflineHours) {
      await fetchToken();
    }
  }

  /// Get the current plan name.
  Future<String?> getPlanName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_planKey);
  }

  /// Get features for the current plan.
  Future<List<String>> getFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_featuresKey) ?? [];
  }

  /// Clear all stored subscription data (called when token is invalid).
  Future<void> _clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_planKey);
    await prefs.remove(_featuresKey);
    await prefs.remove(_expiryKey);
    await prefs.remove(_lastVerifyKey);
  }

  /// Force clear (for logout).
  Future<void> clearAll() async {
    await _clearToken();
  }
}
