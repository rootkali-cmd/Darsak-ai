import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../services/debug_tracker.dart';

final class ApiClient {
  late final Dio dio;
  late final Dio _refreshDio;
  final FlutterSecureStorage _secureStorage;
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;
  void Function()? onUnauthorized;

  ApiClient() : _secureStorage = const FlutterSecureStorage() {
    dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConstants.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConstants.receiveTimeoutSeconds),
      headers: {'Content-Type': 'application/json'},
    ));

    _refreshDio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: Duration(seconds: AppConstants.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConstants.receiveTimeoutSeconds),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Auto-retry on transient network failures
        final retryCount = error.requestOptions.extra['retry_count'] as int? ?? 0;
        if (retryCount < 3 && _isRetryable(error)) {
          await Future.delayed(Duration(seconds: retryCount + 1));
          error.requestOptions.extra['retry_count'] = retryCount + 1;
          try {
            final response = await dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {
            // Let it fall through to normal error handling
          }
        }
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.contains('/auth/refresh')) {
          final retry = await _tryRefreshToken(error);
          if (retry != null) {
            handler.resolve(retry);
            return;
          }
          // Only trigger logout for user-facing requests (dashboard, login, etc.)
          // Background sync ops (students, groups, grades, invoices) should NOT logout
          final path = error.requestOptions.path;
          final isBackgroundSync = path.startsWith('/students/') ||
              path.startsWith('/groups/') ||
              path.startsWith('/grades/') ||
              path.startsWith('/invoices/') ||
              path.startsWith('/attendance/') ||
              path.startsWith('/exams/') ||
              path.startsWith('/qr/') ||
              path.startsWith('/analytics/');
          if (!isBackgroundSync && onUnauthorized != null) {
            onUnauthorized!();
          }
          handler.reject(error);
          return;
        }
        handler.next(error);
      },
    ));
  }

  static bool _isRetryable(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return true;
    }
    final status = error.response?.statusCode;
    return status != null && status >= 500;
  }

  Future<String?> _readToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(PrefKeys.accessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}

    try {
      final token = await _secureStorage.read(key: PrefKeys.accessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}

    return null;
  }

  Future<void> _writeTokens(String accessToken, String? refreshToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefKeys.accessToken, accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString(PrefKeys.refreshToken, refreshToken);
      }
    } catch (_) {}

    try {
      await _secureStorage.write(key: PrefKeys.accessToken, value: accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _secureStorage.write(key: PrefKeys.refreshToken, value: refreshToken);
      }
    } catch (_) {}
  }

  Future<void> _clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PrefKeys.accessToken);
      await prefs.remove(PrefKeys.refreshToken);
    } catch (_) {}

    try {
      await _secureStorage.delete(key: PrefKeys.accessToken);
      await _secureStorage.delete(key: PrefKeys.refreshToken);
    } catch (_) {}
  }

  Future<Response?> _tryRefreshToken(DioException error) async {
    if (_isRefreshing) {
      await _refreshCompleter?.future;
      final newToken = await _readToken();
      if (newToken != null && newToken.isNotEmpty) {
        error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
        return await dio.fetch(error.requestOptions);
      }
      return null;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<void>();
    try {
      String? storedRefreshToken;
      try {
        final prefs = await SharedPreferences.getInstance();
        storedRefreshToken = prefs.getString(PrefKeys.refreshToken);
      } catch (_) {}

      storedRefreshToken ??= await _secureStorage.read(key: PrefKeys.refreshToken);
      if (storedRefreshToken == null || storedRefreshToken.isEmpty) {
        _isRefreshing = false;
        _refreshCompleter?.complete();
        return null;
      }

      final response = await _refreshDio.post('/auth/refresh',
          data: {'refresh_token': storedRefreshToken});
      final newAccessToken = response.data['access_token'] as String?;
      final newRefreshToken = response.data['refresh_token'] as String?;

      if (newAccessToken != null) {
        await _writeTokens(newAccessToken, newRefreshToken);
        error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
        return await dio.fetch(error.requestOptions);
      }
    } on DioException catch (e) {
      // Any refresh failure means the session is dead — clear everything
      await _clearTokens();
      onUnauthorized?.call();
    } catch (e) {
      AppLogger.instance.error('token_refresh_failed', error: e);
      await _clearTokens();
      onUnauthorized?.call();
    } finally {
      _isRefreshing = false;
      _refreshCompleter?.complete();
    }
    return null;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    DebugTracker.instance.apiCall('GET ▶', path);
    final start = DateTime.now();
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      DebugTracker.instance.apiCall('GET ◀', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
      return response.data;
    } catch (e) {
      DebugTracker.instance.apiCall('GET ✖', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? queryParameters}) async {
    DebugTracker.instance.apiCall('GET ▶', path);
    final start = DateTime.now();
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      DebugTracker.instance.apiCall('GET ◀', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
      return response.data is List ? response.data as List : [];
    } catch (e) {
      DebugTracker.instance.apiCall('GET ✖', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    final start = DateTime.now();
    try {
      final response = await dio.post(path, data: data);
      DebugTracker.instance.apiCall('POST', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
      return response.data;
    } catch (e) {
      DebugTracker.instance.apiCall('POST', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    final start = DateTime.now();
    try {
      final response = await dio.patch(path, data: data);
      DebugTracker.instance.apiCall('PATCH', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
      return response.data;
    } catch (e) {
      DebugTracker.instance.apiCall('PATCH', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    final start = DateTime.now();
    try {
      final response = await dio.put(path, data: data);
      DebugTracker.instance.apiCall('PUT', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
      return response.data;
    } catch (e) {
      DebugTracker.instance.apiCall('PUT', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }

  Future<void> delete(String path) async {
    final start = DateTime.now();
    try {
      final response = await dio.delete(path);
      DebugTracker.instance.apiCall('DELETE', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
    } catch (e) {
      DebugTracker.instance.apiCall('DELETE', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadFile(String path, FormData formData) async {
    final start = DateTime.now();
    try {
      final response = await dio.post(path, data: formData);
      DebugTracker.instance.apiCall('UPLOAD', path, statusCode: response.statusCode, latencyMs: DateTime.now().difference(start).inMilliseconds);
      return response.data;
    } catch (e) {
      DebugTracker.instance.apiCall('UPLOAD', path, error: e.toString(), latencyMs: DateTime.now().difference(start).inMilliseconds);
      rethrow;
    }
  }
}
