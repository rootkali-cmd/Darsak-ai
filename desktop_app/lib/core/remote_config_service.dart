import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class RemoteConfig {
  final bool maintenanceMode;
  final bool disableUpdates;
  final bool enableBetaFeatures;
  final String minimumSupportedVersion;
  final bool telemetryEnabled;
  final List<String> blockedVersions;

  RemoteConfig({
    this.maintenanceMode = false,
    this.disableUpdates = false,
    this.enableBetaFeatures = false,
    this.minimumSupportedVersion = '1.0.0',
    this.telemetryEnabled = true,
    this.blockedVersions = const [],
  });

  factory RemoteConfig.fromJson(Map<String, dynamic> json) {
    return RemoteConfig(
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      disableUpdates: json['disable_updates'] as bool? ?? false,
      enableBetaFeatures: json['enable_beta_features'] as bool? ?? false,
      minimumSupportedVersion: json['minimum_supported_version'] as String? ?? '1.0.0',
      telemetryEnabled: json['telemetry_enabled'] as bool? ?? true,
      blockedVersions: (json['blocked_versions'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'maintenance_mode': maintenanceMode,
    'disable_updates': disableUpdates,
    'enable_beta_features': enableBetaFeatures,
    'minimum_supported_version': minimumSupportedVersion,
    'telemetry_enabled': telemetryEnabled,
    'blocked_versions': blockedVersions,
  };
}

class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService _instance = RemoteConfigService._();
  static RemoteConfigService get instance => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConstants.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static const String _cacheKey = 'remote_config_cache';
  RemoteConfig _config = RemoteConfig();
  RemoteConfig get config => _config;
  bool _initialized = false;

  bool get isBlocked {
    return _config.blockedVersions.contains(AppConstants.appVersion);
  }

  bool get isBelowMinimum {
    try {
      final currentParts = AppConstants.appVersion.split('.').map(int.parse).toList();
      final minParts = _config.minimumSupportedVersion.split('.').map(int.parse).toList();
      final maxLen = currentParts.length > minParts.length ? currentParts.length : minParts.length;
      while (currentParts.length < maxLen) currentParts.add(0);
      while (minParts.length < maxLen) minParts.add(0);
      for (int i = 0; i < maxLen; i++) {
        if (currentParts[i] < minParts[i]) return true;
        if (currentParts[i] > minParts[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadCached();
    _fetch();
  }

  Future<void> _loadCached() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) {
        _config = RemoteConfig.fromJson(jsonDecode(raw));
      }
    } catch (_) {}
  }

  Future<void> _cache(RemoteConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(config.toJson()));
    } catch (_) {}
  }

  Future<void> _fetch() async {
    try {
      final response = await _dio.get('/config/client');
      if (response.statusCode == 200) {
        _config = RemoteConfig.fromJson(response.data);
        _cache(_config);
      }
    } catch (_) {}
  }

  Future<void> refresh() async {
    await _fetch();
  }
}
