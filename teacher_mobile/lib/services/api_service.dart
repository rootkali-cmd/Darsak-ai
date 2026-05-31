import 'dart:async';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://darsak-backend.fly.dev/api';
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  bool _isRefreshing = false;
  Completer<bool>? _refreshCompleter;

  static bool _forceLogout = false;
  static bool get forceLogout => _forceLogout;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      followRedirects: true,
      maxRedirects: 5,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
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
      onError: (error, handler) async {
        // Only retry on 401
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          final refresh = prefs.getString('refresh_token');

          if (refresh == null || refresh.isEmpty) {
            return handler.next(error);
          }

          // Wait if another request is already refreshing
          if (_isRefreshing && _refreshCompleter != null) {
            final success = await _refreshCompleter!.future;
            if (success) {
              final token = prefs.getString('access_token') ?? '';
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              try {
                final retry = await _dio.fetch(error.requestOptions);
                return handler.resolve(retry);
              } catch (_) {}
            }
            return handler.next(error);
          }

          // Try refresh with lock
          _isRefreshing = true;
          _refreshCompleter = Completer<bool>();

          try {
            final plainDio = Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ));

            final refreshResponse = await plainDio.post('/auth/refresh',
              data: {'refresh_token': refresh},
            );

            final newToken = refreshResponse.data['access_token'] as String?;
            final newRefresh = refreshResponse.data['refresh_token'] as String?;

            if (newToken != null && newToken.isNotEmpty) {
              await prefs.setString('access_token', newToken);
              if (newRefresh != null) {
                await prefs.setString('refresh_token', newRefresh);
              }

              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retryResponse = await _dio.fetch(error.requestOptions);
              _refreshCompleter!.complete(true);
              _isRefreshing = false;
              return handler.resolve(retryResponse);
            }
          } catch (e) {
            // If refresh returns 401, tokens are expired/blacklisted — clear them
            if (e is DioException && e.response?.statusCode == 401) {
              await prefs.remove('access_token');
              await prefs.remove('refresh_token');
              _forceLogout = true;
            }
          }

          _refreshCompleter?.complete(false);
          _isRefreshing = false;
        }

        // Retry on connection timeout (no response)
        if (error.response == null && error.type != DioExceptionType.cancel) {
          try {
            await Future.delayed(const Duration(seconds: 2));
            final retry = await _dio.fetch(error.requestOptions);
            return handler.resolve(retry);
          } catch (_) {}
        }

        return handler.next(error);
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
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> getStudent(int id) async {
    final response = await _dio.get('/students/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    final response = await _dio.post('/students', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateStudent(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/students/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteStudent(int id) async {
    await _dio.delete('/students/$id');
  }

  Future<int> getStudentsCount() async {
    final response = await _dio.get('/students/count');
    return response.data['count'] as int? ?? 0;
  }

  // Groups
  Future<List<dynamic>> getGroups() async {
    final response = await _dio.get('/groups');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final response = await _dio.post('/groups', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGroup(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/groups/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteGroup(int id) async {
    await _dio.delete('/groups/$id');
  }

  // Attendance
  Future<List<dynamic>> getAttendance({String? date}) async {
    final query = <String, dynamic>{};
    if (date != null) query['date'] = date;
    final response = await _dio.get('/attendance', queryParameters: query);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) async {
    final response = await _dio.post('/attendance', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAttendanceByBarcode(String barcode) async {
    final response = await _dio.post('/attendance/barcode', data: {'barcode': barcode});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markBulkAttendance(List<Map<String, dynamic>> records) async {
    final response = await _dio.post('/attendance/bulk', data: {'records': records});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttendanceStats() async {
    final response = await _dio.get('/attendance/stats');
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getStudentAttendance(int studentId) async {
    final response = await _dio.get('/students/$studentId/attendance');
    return response.data as List<dynamic>;
  }

  // Grades
  Future<List<dynamic>> getGrades({String? subject}) async {
    final response = await _dio.get('/grades', queryParameters: {
      if (subject != null && subject.isNotEmpty) 'subject': subject,
    });
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGrade(Map<String, dynamic> data) async {
    final response = await _dio.post('/grades', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGrade(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/grades/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteGrade(int id) async {
    await _dio.delete('/grades/$id');
  }

  Future<List<dynamic>> getStudentGrades(int studentId) async {
    final response = await _dio.get('/students/$studentId/grades');
    return response.data as List<dynamic>;
  }

  // Invoices
  Future<List<dynamic>> getInvoices() async {
    final response = await _dio.get('/invoices');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final response = await _dio.post('/invoices', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateInvoice(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/invoices/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteInvoice(int id) async {
    await _dio.delete('/invoices/$id');
  }

  Future<Map<String, dynamic>> getInvoiceStats() async {
    final response = await _dio.get('/invoices/stats');
    return response.data as Map<String, dynamic>;
  }

  // Exams
  Future<List<dynamic>> getExams() async {
    final response = await _dio.get('/exams');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getExam(int id) async {
    final response = await _dio.get('/exams/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createExam(Map<String, dynamic> data) async {
    final response = await _dio.post('/exams', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateExam(int id, Map<String, dynamic> data) async {
    final response = await _dio.put('/exams/$id', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteExam(int id) async {
    await _dio.delete('/exams/$id');
  }
}
