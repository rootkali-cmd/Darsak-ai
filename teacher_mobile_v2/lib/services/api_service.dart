import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  late final Dio _aiDio;
  static const _baseUrl = 'https://darsak-backend.fly.dev/api';
  static const _tokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  final _secureStorage = const FlutterSecureStorage();

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
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.read(key: _tokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _tryRefreshToken();
          if (refreshed && error.requestOptions.path != '/auth/refresh') {
            final newToken = await _secureStorage.read(key: _tokenKey);
            if (newToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryCount = (error.requestOptions.extra['_retry'] ?? 0) as int;
              if (retryCount < 2) {
                error.requestOptions.extra['_retry'] = retryCount + 1;
                final clone = await dio.fetch(error.requestOptions);
                handler.resolve(clone);
                return;
              }
            }
          }
          await _clearAuth();
        }
        handler.next(error);
      },
    ));

    return dio;
  }

  Future<bool> _tryRefreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      if (refreshToken == null) return false;

      final refreshDio = Dio(BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ));

      try {
        final resp = await refreshDio.post('/auth/refresh', data: {
          'refresh_token': refreshToken,
        });

        final newAccess = resp.data['access_token'] as String?;
        final newRefresh = resp.data['refresh_token'] as String?;

        if (newAccess != null) {
          await _secureStorage.write(key: _tokenKey, value: newAccess);
          if (newRefresh != null) {
            await _secureStorage.write(key: _refreshTokenKey, value: newRefresh);
          }
          return true;
        }
        return false;
      } finally {
        refreshDio.close();
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearAuth() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
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
      final accessToken = data['access_token'].toString();
      await _secureStorage.write(key: _tokenKey, value: accessToken);
      if (data['refresh_token'] != null) {
        final refreshToken = data['refresh_token'].toString();
        await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
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
  Future<Map<String, dynamic>> getStudents({int? page, int? limit, String? search}) async {
    final query = <String, dynamic>{};
    if (page != null) query['page'] = page;
    if (limit != null) query['limit'] = limit;
    if (search != null && search.isNotEmpty) query['search'] = search;
    final res = await _dio.get('/students', queryParameters: query);
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
}
