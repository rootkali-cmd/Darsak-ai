import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  Future<Response> _directRequest(RequestOptions opts) async {
    final token = await _storage.read(key: AppConstants.storageKeyToken);
    final headers = <String, dynamic>{
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 45),
    ));
    try {
      return await dio.request(
        opts.uri.toString(),
        data: opts.data,
        queryParameters: opts.queryParameters,
        options: Options(
          method: opts.method,
          headers: headers,
          receiveTimeout: const Duration(seconds: 45),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
    } finally {
      dio.close();
    }
  }

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
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
      onError: (error, handler) async {
        // Retry on SocketException (DNS/host lookup failure) up to 2 times
        if (error.type == DioExceptionType.connectionError &&
            error.error is SocketException) {
          for (int i = 0; i < 2; i++) {
            await Future.delayed(Duration(seconds: 2 * (i + 1)));
            try {
              final retry = await _directRequest(error.requestOptions);
              handler.resolve(retry);
              return;
            } catch (_) {}
          }
        }
        if (error.response?.statusCode != 401) {
          handler.next(error);
          return;
        }

        // ── Decide who does the refresh ──
        Completer<void>? waiter;
        if (!_isRefreshing) {
          _isRefreshing = true;
          _refreshCompleter = Completer<void>();
        } else {
          waiter = _refreshCompleter;
        }

        if (waiter != null) {
          // Another request is refreshing; wait and retry with stored token
          await waiter.future;
          final token = await _storage.read(key: AppConstants.storageKeyToken);
          if (token != null) {
            try {
              final retry = await _directRequest(error.requestOptions);
              handler.resolve(retry);
              return;
            } catch (_) {}
          }
          handler.next(error);
          return;
        }

        // ── This request does the refresh ──
        final refreshToken = await _storage.read(key: AppConstants.storageKeyRefreshToken);
        if (refreshToken == null) {
          _isRefreshing = false;
          _refreshCompleter?.complete();
          _refreshCompleter = null;
          handler.next(error);
          return;
        }

        try {
          final dio = Dio(BaseOptions(
            baseUrl: AppConstants.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ));
          final response = await dio.post('/students/refresh', data: {
            'refresh_token': refreshToken,
          });
          final data = response.data;
          final newAccessToken = data['access_token'] as String?;
          final newRefreshToken = data['refresh_token'] as String?;
          if (newAccessToken != null) {
            await _storage.write(key: AppConstants.storageKeyToken, value: newAccessToken);
            if (newRefreshToken != null) {
              await _storage.write(key: AppConstants.storageKeyRefreshToken, value: newRefreshToken);
            }
            final retryResponse = await _directRequest(error.requestOptions);
            handler.resolve(retryResponse);
            return;
          }
        } catch (_) {
        } finally {
          _isRefreshing = false;
          _refreshCompleter?.complete();
          _refreshCompleter = null;
        }
        handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>> verifyTeacher(String teacherCode) async {
    final response = await _dio.post('/students/verify-teacher', data: {
      'teacher_code': teacherCode,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> login(String code, String pin, {String? teacherCode}) async {
    final response = await _dio.post('/students/login', data: {
      'code': code,
      'pin': pin,
      if (teacherCode != null) 'teacher_code': teacherCode,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get('/students/me');
    return response.data;
  }

  Future<List<dynamic>> getGrades({String? subject}) async {
    final response = await _dio.get('/students/me/grades', queryParameters: {
      'subject': subject,
    });
    return response.data;
  }

  Future<List<dynamic>> getAttendance({String? fromDate, String? toDate}) async {
    final response = await _dio.get('/students/me/attendance', queryParameters: {
      'from_date': fromDate,
      'to_date': toDate,
    });
    return response.data;
  }

  Future<List<dynamic>> getInvoices() async {
    final response = await _dio.get('/students/me/invoices');
    return response.data;
  }

  Future<void> changePin(String oldPin, String newPin) async {
    await _dio.patch('/students/me/pin', data: {
      'old_pin': oldPin,
      'new_pin': newPin,
    });
  }

  Future<Map<String, dynamic>> getMySubscription() async {
    final response = await _dio.get('/subscriptions/my');
    return response.data;
  }

  Future<Map<String, dynamic>> activateCode(String code) async {
    final response = await _dio.post('/subscriptions/activate', data: {
      'code': code,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> checkVersion() async {
    final response = await _dio.get('/versions/android');
    return response.data;
  }

  Future<Map<String, dynamic>> checkInQR({
    required String teacherId,
    required String groupId,
    String? lectureDate,
  }) async {
    final response = await _dio.post('/qr/student-checkin', data: {
      'teacher_id': teacherId,
      'group_id': groupId,
      'lecture_date': lectureDate,
    });
    return response.data;
  }

  Dio get dio => _dio;

  // ─── Exam / Quiz System ──────────────────────────────────────────

  Future<List<dynamic>> getAvailableExams() async {
    final response = await _dio.get('/exams/available');
    return response.data is List ? response.data as List : [];
  }

  Future<Map<String, dynamic>> startExam(String examId) async {
    final response = await _dio.post('/exams/$examId/start');
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getExamQuestions(String examId) async {
    final response = await _dio.get('/exams/$examId/questions-student');
    return response.data is List ? response.data as List : [];
  }

  Future<Map<String, dynamic>> submitExam(String examId, List<Map<String, dynamic>> answers) async {
    final response = await _dio.post('/exams/$examId/submit', data: {
      'answers': answers,
    });
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getMyExamResults() async {
    final response = await _dio.get('/exams/my-results');
    return response.data is List ? response.data as List : [];
  }

  Future<Map<String, dynamic>> getStudentExamResult(String studentExamId) async {
    final response = await _dio.get('/exams/my-result/$studentExamId');
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getStudentStats() async {
    final response = await _dio.get('/students/me/stats');
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  // ─── Notifications ─────────────────────────────────────────────────

  Future<List<dynamic>> getNotifications() async {
    final response = await _dio.get('/students/me/notifications');
    return response.data is List ? response.data as List : [];
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _dio.post('/students/me/notifications/$notificationId/read');
  }
}
