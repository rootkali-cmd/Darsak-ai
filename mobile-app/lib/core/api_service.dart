import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;

  ApiService._internal() {
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
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && !_isRefreshing) {
          final refreshToken = await _storage.read(key: AppConstants.storageKeyRefreshToken);
          if (refreshToken != null) {
            _isRefreshing = true;
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
                // Retry the original request with new token
                error.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
                final retryResponse = await _dio.fetch(error.requestOptions);
                handler.resolve(retryResponse);
                return;
              }
            } catch (_) {
              // Refresh failed — fall through to original error
            } finally {
              _isRefreshing = false;
            }
          }
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
      'teacher_code': ?teacherCode,
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
}
