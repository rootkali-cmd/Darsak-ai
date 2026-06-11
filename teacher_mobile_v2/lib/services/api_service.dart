import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  static const _baseUrl = 'https://darsak-backend.fly.dev/api';

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) => handler.next(error),
    ));
  }

  Dio get dio => _dio;

  Dio get aiDio {
    final ai = Dio(_dio.options);
    ai.options.receiveTimeout = const Duration(seconds: 180);
    ai.options.sendTimeout = const Duration(seconds: 180);
    ai.interceptors.addAll(_dio.interceptors);
    return ai;
  }

  Future<Map<String, dynamic>> _parseResponse(Response response) async {
    if (response.data is Map<String, dynamic>) return response.data;
    if (response.data is String) return {'data': response.data};
    return {'data': response.data};
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return _parseResponse(res);
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
