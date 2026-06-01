import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://darsak-backend.fly.dev/api';
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 90),
      receiveTimeout: const Duration(seconds: 90),
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      validateStatus: (s) => s != null && s < 500,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }

  Dio get dio => _dio;

  /// Wake up the Fly.io server (cold start) without auth
  Future<bool> ping() async {
    try {
      final response = await _dio.get('/config/client',
        options: Options(
          sendTimeout: const Duration(seconds: 90),
          receiveTimeout: const Duration(seconds: 90),
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid login response');
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid user data');
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _dio.post('/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    return response.data as Map<String, dynamic>;
  }

  // Dashboard
  Future<Map<String, dynamic>> getDashboardStats() async {
    final response = await _dio.get('/dashboard/stats');
    return response.data as Map<String, dynamic>;
  }

  // Students
  Future<List<dynamic>> getStudents({String? search}) async {
    final query = <String, dynamic>{};
    if (search != null && search.isNotEmpty) query['search'] = search;
    final response = await _dio.get('/students/', queryParameters: query.isNotEmpty ? query : null);
    final data = response.data;
    if (data is Map && data.containsKey('data')) {
      return data['data'] as List<dynamic>;
    }
    if (data is List) return data;
    return [];
  }

  Future<Map<String, dynamic>> getStudent(dynamic id) async {
    final response = await _dio.get('/students/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    final response = await _dio.post('/students/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStudent(dynamic id, Map<String, dynamic> data) async {
    final response = await _dio.put('/students/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteStudent(dynamic id) async {
    await _dio.delete('/students/$id');
  }

  Future<int> getStudentsCount() async {
    final response = await _dio.get('/students/count/');
    return response.data['count'] as int? ?? 0;
  }

  // Groups
  Future<List<dynamic>> getGroups() async {
    final response = await _dio.get('/groups/');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final response = await _dio.post('/groups/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGroup(dynamic id, Map<String, dynamic> data) async {
    final response = await _dio.put('/groups/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteGroup(dynamic id) async {
    await _dio.delete('/groups/$id');
  }

  // Attendance
  Future<List<dynamic>> getAttendance({String? date}) async {
    final query = <String, dynamic>{};
    if (date != null) query['date'] = date;
    final response = await _dio.get('/attendance/', queryParameters: query);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) async {
    final response = await _dio.post('/attendance/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAttendanceByBarcode(String barcode) async {
    final response = await _dio.post('/attendance/barcode', data: {'barcode': barcode});
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Invalid response from server');
  }

  Future<Map<String, dynamic>> markBulkAttendance(List<Map<String, dynamic>> records) async {
    final response = await _dio.post('/attendance/bulk/', data: {'records': records});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceStats() async {
    final response = await _dio.get('/attendance/stats/');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getStudentAttendance(dynamic studentId) async {
    final response = await _dio.get('/students/$studentId/attendance/');
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  // Grades
  Future<List<dynamic>> getGrades({String? subject}) async {
    final response = await _dio.get('/grades/', queryParameters: {
      if (subject != null && subject.isNotEmpty) 'subject': subject,
    });
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGrade(Map<String, dynamic> data) async {
    final response = await _dio.post('/grades/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGrade(dynamic id, Map<String, dynamic> data) async {
    final response = await _dio.put('/grades/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteGrade(dynamic id) async {
    await _dio.delete('/grades/$id');
  }

  Future<List<dynamic>> getStudentGrades(dynamic studentId) async {
    final response = await _dio.get('/students/$studentId/grades/');
    final data = response.data;
    if (data is List) return data;
    return [];
  }

  // Invoices
  Future<List<dynamic>> getInvoices() async {
    final response = await _dio.get('/invoices/');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final response = await _dio.post('/invoices/', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateInvoice(dynamic id, Map<String, dynamic> data) async {
    final response = await _dio.put('/invoices/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteInvoice(dynamic id) async {
    await _dio.delete('/invoices/$id');
  }

  Future<Map<String, dynamic>> getInvoiceStats() async {
    final response = await _dio.get('/invoices/stats/');
    return response.data as Map<String, dynamic>;
  }

  // Exams
  Future<List<dynamic>> getExams() async {
    final response = await _dio.get('/exams');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getExam(dynamic id) async {
    final response = await _dio.get('/exams/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> data) async {
    final response = await _dio.post('/exams', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateExam(dynamic id, Map<String, dynamic> data) async {
    final response = await _dio.put('/exams/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteExam(dynamic id) async {
    await _dio.delete('/exams/$id');
  }
}
