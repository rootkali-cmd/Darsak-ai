import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  late final Dio _aiDio;
  static const _baseUrl = 'https://darsak-backend.fly.dev/api';
  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  
  bool _isRefreshing = false;
  Completer<void>? _refreshCompleter;

  ApiService._internal() {
    _dio = _createDio();
    _aiDio = _createDio();
    _aiDio.options.receiveTimeout = const Duration(seconds: 180);
    _aiDio.options.sendTimeout = const Duration(seconds: 180);
  }

  Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
      sendTimeout: const Duration(minutes: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && error.requestOptions.path != '/auth/refresh') {
          // Concurrency lock — only one refresh at a time
          Completer<void>? waiter;
          if (!_isRefreshing) {
            _isRefreshing = true;
            _refreshCompleter = Completer<void>();
          } else {
            waiter = _refreshCompleter;
          }
          
          if (waiter != null) {
            await waiter.future;
            // Refresh already done by another request — retry with new token
            final prefs = await SharedPreferences.getInstance();
            final newToken = prefs.getString(_tokenKey);
            if (newToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryCount = (error.requestOptions.extra['_retry'] ?? 0) as int;
              if (retryCount < 2) {
                error.requestOptions.extra['_retry'] = retryCount + 1;
                final clone = await _dio.fetch(error.requestOptions);
                handler.resolve(clone);
                return;
              }
            }
            handler.next(error);
            return;
          }
          
          try {
            final refreshed = await tryRefreshToken();
            if (refreshed) {
              final prefs = await SharedPreferences.getInstance();
              final newToken = prefs.getString(_tokenKey);
              if (newToken != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                final retryCount = (error.requestOptions.extra['_retry'] ?? 0) as int;
                if (retryCount < 2) {
                  error.requestOptions.extra['_retry'] = retryCount + 1;
                  final clone = await _dio.fetch(error.requestOptions);
                  handler.resolve(clone);
                  return;
                }
              }
            }
            // Refresh failed
            await _clearAuth();
          } finally {
            _isRefreshing = false;
            _refreshCompleter?.complete();
            _refreshCompleter = null;
          }
        }
        handler.next(error);
      },
    ));

    return dio;
  }

  Future<bool> tryRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(_refreshTokenKey);
      if (refreshToken == null) return false;

      final refreshDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));

      final resp = await refreshDio.post('/auth/refresh', data: {
        'refresh_token': refreshToken,
      });

      final newAccess = resp.data['access_token'] as String?;
      final newRefresh = resp.data['refresh_token'] as String?;

      if (newAccess != null) {
        await prefs.setString(_tokenKey, newAccess);
        if (newRefresh != null) {
          await prefs.setString(_refreshTokenKey, newRefresh);
        }
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  Dio get dio => _dio;

  Dio get aiDio => _aiDio;

  Future<Map<String, dynamic>> _parseResponse(Response response) async {
    if (response.data is Map<String, dynamic>) return response.data;
    if (response.data is String) return {'data': response.data};
    return {'data': response.data};
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    final data = await _parseResponse(res);
    if (data['access_token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      final accessToken = data['access_token'].toString();
      await prefs.setString(_tokenKey, accessToken);
      if (data['refresh_token'] != null) {
        final refreshToken = data['refresh_token'].toString();
        await prefs.setString(_refreshTokenKey, refreshToken);
      }
    }
    return data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get('/auth/me');
    return _parseResponse(res);
  }

  // Dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final res = await _dio.get('/dashboard/stats');
    return _parseResponse(res);
  }

  // Students CRUD
  Future<Map<String, dynamic>> getStudents({int? page, int? limit, String? search, bool includeInactive = true}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (search != null && search.isNotEmpty) query['search'] = search;
    query['include_inactive'] = includeInactive;
    final res = await _dio.get('/students/', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> getStudent(String id) async {
    final res = await _dio.get('/students/$id');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    final res = await _dio.post('/students', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateStudent(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/students/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteStudent(String id) async {
    final res = await _dio.delete('/students/$id');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> getStudentsCount() async {
    final res = await _dio.get('/students/count');
    return _parseResponse(res);
  }

  // Groups CRUD
  Future<Map<String, dynamic>> getGroups({int? page, int? limit}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    final res = await _dio.get('/groups', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> getGroup(String id) async {
    final res = await _dio.get('/groups/$id');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final res = await _dio.post('/groups', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateGroup(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/groups/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteGroup(String id) async {
    final res = await _dio.delete('/groups/$id');
    return _parseResponse(res);
  }

  // Attendance
  Future<Map<String, dynamic>> getAttendance({int? page, int? limit, String? groupId}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (groupId != null) query['group_id'] = groupId;
    final res = await _dio.get('/attendance', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createAttendance(Map<String, dynamic> data) async {
    final res = await _dio.post('/attendance', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateAttendance(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/attendance/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteAttendance(String id) async {
    final res = await _dio.delete('/attendance/$id');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> markAttendanceByBarcode(String barcode) async {
    final res = await _dio.post('/attendance/barcode', data: {'barcode': barcode});
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> getAttendanceStats() async {
    final res = await _dio.get('/attendance/stats');
    return _parseResponse(res);
  }

  // Grades
  Future<Map<String, dynamic>> getGrades({int? page, int? limit, String? studentId}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (studentId != null) query['student_id'] = studentId;
    final res = await _dio.get('/grades', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createGrade(Map<String, dynamic> data) async {
    final res = await _dio.post('/grades', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateGrade(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/grades/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteGrade(String id) async {
    final res = await _dio.delete('/grades/$id');
    return _parseResponse(res);
  }

  // Invoices
  Future<Map<String, dynamic>> getInvoices({int? page, int? limit, String? studentId}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (studentId != null) query['student_id'] = studentId;
    final res = await _dio.get('/invoices', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateInvoice(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/invoices/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteInvoice(String id) async {
    final res = await _dio.delete('/invoices/$id');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> getInvoiceStats() async {
    final res = await _dio.get('/invoices/stats');
    return _parseResponse(res);
  }

  // Invoice Actions
  Future<Map<String, dynamic>> getPendingInvoices() async {
    final res = await _dio.get('/invoices/pending');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> approveInvoice(String id) async {
    final res = await _dio.post('/invoices/$id/approve');
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> rejectInvoice(String id) async {
    final res = await _dio.post('/invoices/$id/reject');
    return _parseResponse(res);
  }

  // Exams
  Future<Map<String, dynamic>> getExams({int? page, int? limit, String? groupId}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (groupId != null) query['group_id'] = groupId;
    final res = await _dio.get('/exams', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> data) async {
    final res = await _dio.post('/exams', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateExam(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/exams/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteExam(String id) async {
    final res = await _dio.delete('/exams/$id');
    return _parseResponse(res);
  }

  // Lessons
  Future<Map<String, dynamic>> getLessons({int? page, int? limit, String? groupId}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (groupId != null) query['group_id'] = groupId;
    final res = await _dio.get('/lessons', queryParameters: query);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> createLesson(Map<String, dynamic> data) async {
    final res = await _dio.post('/lessons', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> updateLesson(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/lessons/$id', data: data);
    return _parseResponse(res);
  }

  Future<Map<String, dynamic>> deleteLesson(String id) async {
    final res = await _dio.delete('/lessons/$id');
    return _parseResponse(res);
  }

  // Wallet
  Future<Map<String, dynamic>> getWallet() async {
    final res = await _dio.get('/wallet');
    return _parseResponse(res);
  }
  Future<Map<String, dynamic>> requestPayout(double amount, String method, String phone) async {
    final res = await _dio.post('/wallet/payout-request', data: {'amount': amount, 'payout_method': method, 'payout_phone': phone});
    return _parseResponse(res);
  }
  Future<Map<String, dynamic>> getPayoutRequests({int limit = 50}) async {
    final res = await _dio.get('/wallet/payout-requests', queryParameters: {'limit': limit});
    return _parseResponse(res);
  }
  Future<Map<String, dynamic>> getWalletTransactions({int limit = 50}) async {
    final res = await _dio.get('/wallet/transactions', queryParameters: {'limit': limit});
    return _parseResponse(res);
  }
  Future<Map<String, dynamic>> getFinanceOverview() async {
    final res = await _dio.get('/finance/overview');
    return _parseResponse(res);
  }

  // Lesson Lock
  Future<void> setLessonLock(String lessonId, Map<String, dynamic>? data) async {
    if (data == null) {
      await _dio.put('/courses/lessons/$lessonId/lock', data: {'lock_type': null});
    } else {
      await _dio.put('/courses/lessons/$lessonId/lock', data: data);
    }
  }

  // ── Course Management ──
  Future<void> reportError(String screen, String error, {Map<String, dynamic>? extra}) async {
    try {
      String teacherId = 'unknown';
      String teacherName = 'unknown';
      try {
        final me = await getMe();
        teacherId = me['id']?.toString() ?? 'unknown';
        teacherName = me['name']?.toString() ?? me['email']?.toString() ?? 'unknown';
      } catch (_) {}
      final fallbackDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {'Content-Type': 'application/json'},
      ));
      await fallbackDio.post('/report-error', data: {
        'screen': screen,
        'error': error,
        'teacher_id': teacherId,
        'teacher_name': teacherName,
        'extra': extra ?? {},
      });
    } catch (_) {}
  }

  Future<List<dynamic>> getCourses() async {
    final res = await _dio.get('/courses');
    if (res.data is Map && res.data['items'] is List) return res.data['items'] as List;
    return [];
  }

  Future<Map<String, dynamic>> getCourse(String courseId) async {
    final res = await _dio.get('/courses/$courseId');
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    final res = await _dio.post('/courses', data: data);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<Map<String, dynamic>> updateCourse(String courseId, Map<String, dynamic> data) async {
    final res = await _dio.put('/courses/$courseId', data: data);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<void> deleteCourse(String courseId) async {
    await _dio.delete('/courses/$courseId/delete');
  }

  Future<Map<String, dynamic>> updateCoursePricing(String courseId, Map<String, dynamic> data) async {
    final res = await _dio.put('/courses/$courseId/pricing', data: data);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<Map<String, dynamic>> uploadCourseCover(String courseId, String filePath, {void Function(int sent, int total)? onProgress}) async {
    final file = await MultipartFile.fromFile(filePath, filename: 'cover.jpg');
    final form = FormData.fromMap({'file': file});
    final res = await _dio.post('/courses/$courseId/cover', data: form, onSendProgress: onProgress);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  // ── Chapter Management ──
  Future<List<dynamic>> getChapters(String courseId) async {
    final res = await _dio.get('/courses/$courseId/chapters');
    if (res.data is Map && res.data['items'] is List) return res.data['items'] as List;
    return [];
  }

  Future<Map<String, dynamic>> createChapter(String courseId, Map<String, dynamic> data) async {
    final res = await _dio.post('/courses/$courseId/chapters', data: data);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<void> deleteChapter(String chapterId) async {
    await _dio.delete('/courses/chapters/$chapterId/delete');
  }

  // ── Course Lesson Management ──
  Future<List<dynamic>> getCourseLessons(String chapterId) async {
    final res = await _dio.get('/courses/chapters/$chapterId/lessons');
    if (res.data is Map && res.data['items'] is List) return res.data['items'] as List;
    return [];
  }

  Future<Map<String, dynamic>> getCourseLesson(String lessonId) async {
    final res = await _dio.get('/courses/lessons/$lessonId');
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<Map<String, dynamic>> createCourseLesson(String chapterId, Map<String, dynamic> data) async {
    final res = await _dio.post('/courses/chapters/$chapterId/lessons', data: data);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<Map<String, dynamic>> updateCourseLesson(String lessonId, Map<String, dynamic> data) async {
    final res = await _dio.put('/courses/lessons/$lessonId', data: data);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<void> deleteCourseLesson(String lessonId) async {
    await _dio.delete('/courses/lessons/$lessonId/delete');
  }

  Future<Map<String, dynamic>> uploadLessonVideo(String lessonId, String filePath, {void Function(int sent, int total)? onProgress}) async {
    final file = await MultipartFile.fromFile(filePath, filename: 'video.mp4');
    final form = FormData.fromMap({'file': file});
    final res = await _dio.post('/courses/lessons/$lessonId/video', data: form, onSendProgress: onProgress);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<Map<String, dynamic>> uploadLessonFile(String lessonId, String filePath, String fileName, {void Function(int sent, int total)? onProgress}) async {
    final file = await MultipartFile.fromFile(filePath, filename: fileName);
    final form = FormData.fromMap({'file': file});
    final res = await _dio.post('/courses/lessons/$lessonId/file', data: form, onSendProgress: onProgress);
    if (res.data is Map && res.data['data'] is Map) return Map<String, dynamic>.from(res.data['data']);
    return {};
  }

  Future<List<dynamic>> getLessonFiles(String lessonId) async {
    final res = await _dio.get('/courses/lessons/$lessonId/files');
    if (res.data is Map && res.data['items'] is List) return res.data['items'] as List;
    return [];
  }

  Future<void> deleteCourseFile(String fileId) async {
    await _dio.delete('/courses/files/$fileId/delete');
  }

  // ── Course Lesson Exam Questions ──
  Future<List<dynamic>> getLessonExamQuestions(String lessonId) async {
    final res = await _dio.get('/courses/lessons/$lessonId/exam-questions');
    if (res.data is Map && res.data['questions'] is List) return res.data['questions'] as List;
    return [];
  }

  Future<Map<String, dynamic>> addLessonExamQuestion(String lessonId, Map<String, dynamic> data) async {
    final res = await _dio.post('/courses/lessons/$lessonId/exam-questions', data: data);
    return res.data is Map<String, dynamic> ? Map<String, dynamic>.from(res.data) : {};
  }

  Future<Map<String, dynamic>> updateLessonExamQuestion(String lessonId, String questionId, Map<String, dynamic> data) async {
    final res = await _dio.put('/courses/lessons/$lessonId/exam-questions/$questionId', data: data);
    return res.data is Map<String, dynamic> ? Map<String, dynamic>.from(res.data) : {};
  }

  Future<void> deleteLessonExamQuestion(String lessonId, String questionId) async {
    await _dio.delete('/courses/lessons/$lessonId/exam-questions/$questionId');
  }

  Future<List<dynamic>> generateLessonExamQuestionsAI(String lessonId, {String subject = '', int questionCount = 10, String? pdfBase64}) async {
    final res = await _dio.post('/courses/lessons/$lessonId/exam-questions/generate-ai', data: {
      'subject': subject,
      'question_count': questionCount,
      if (pdfBase64 != null) 'pdf_base64': pdfBase64,
    });
    if (res.data is Map && res.data['questions'] is List) return res.data['questions'] as List;
    return [];
  }

  // ── Admission Queue ──
  Future<Map<String, dynamic>> getPendingAdmissions() async {
    final res = await _dio.get('/admission/pending');
    return res.data is Map<String, dynamic> ? Map<String, dynamic>.from(res.data) : {'items': []};
  }

  Future<Map<String, dynamic>> approveAdmission(String id) async {
    final res = await _dio.post('/admission/$id/approve');
    return res.data is Map<String, dynamic> ? Map<String, dynamic>.from(res.data) : {};
  }

  Future<void> rejectAdmission(String id, {String? reason}) async {
    await _dio.post('/admission/$id/reject', data: {'reason': reason});
  }
}
