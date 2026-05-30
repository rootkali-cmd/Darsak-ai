import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

final class ApiClient {
  late final Dio dio;
  late final Dio _refreshDio;
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;
  void Function()? onUnauthorized;

  ApiClient() {
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
        final retryCount = error.requestOptions.extra['retry_count'] as int? ?? 0;
        if (retryCount < 3 && _isRetryable(error)) {
          await Future.delayed(Duration(seconds: retryCount + 1));
          error.requestOptions.extra['retry_count'] = retryCount + 1;
          try {
            final response = await dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {}
        }
        if (error.response?.statusCode == 401 &&
            !error.requestOptions.path.contains('/auth/refresh')) {
          final retry = await _tryRefreshToken(error);
          if (retry != null) {
            handler.resolve(retry);
            return;
          }
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
      return prefs.getString(PrefKeys.accessToken);
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
  }

  Future<void> _clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(PrefKeys.accessToken);
      await prefs.remove(PrefKeys.refreshToken);
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
    } on DioException catch (_) {
      await _clearTokens();
      onUnauthorized?.call();
    } catch (_) {
      await _clearTokens();
      onUnauthorized?.call();
    } finally {
      _isRefreshing = false;
      _refreshCompleter?.complete();
    }
    return null;
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await dio.get(path, queryParameters: queryParameters);
    return response.data;
  }

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? queryParameters}) async {
    final response = await dio.get(path, queryParameters: queryParameters);
    return response.data is List ? response.data as List : [];
  }

  Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? data}) async {
    final response = await dio.post(path, data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? data}) async {
    final response = await dio.patch(path, data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? data}) async {
    final response = await dio.put(path, data: data);
    return response.data;
  }

  Future<void> delete(String path) async {
    await dio.delete(path);
  }

  Future<Map<String, dynamic>> uploadFile(String path, FormData formData) async {
    final response = await dio.post(path, data: formData);
    return response.data;
  }
}
