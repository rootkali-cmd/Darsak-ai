import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          final refreshToken = prefs.getString('refresh_token');
          if (refreshToken != null) {
            try {
              final response = await _dio.post('/auth/refresh',
                  data: {'refresh_token': refreshToken});
              final newToken = response.data['access_token'];
              final newRefresh = response.data['refresh_token'];
              await prefs.setString('access_token', newToken);
              await prefs.setString('refresh_token', newRefresh);

              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              final retry = await _dio.fetch(error.requestOptions);
              handler.resolve(retry);
              return;
            } catch (_) {}
          }
          await prefs.remove('access_token');
          await prefs.remove('refresh_token');
        }
        handler.next(error);
      },
    ));
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post('/auth/login',
        data: {'email': email, 'password': password});
    return response.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<List<dynamic>> getStudents({String? search}) async {
    final response = await _dio.get('/students/',
        queryParameters: {'search': search});
    return response.data;
  }

  Future<Map<String, dynamic>> getStudent(String id) async {
    final response = await _dio.get('/students/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) async {
    final response = await _dio.post('/students/', data: data);
    return response.data;
  }

  Future<List<dynamic>> getGroups() async {
    final response = await _dio.get('/groups/');
    return response.data;
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final response = await _dio.post('/groups/', data: data);
    return response.data;
  }

  Future<List<dynamic>> getAttendance({String? groupId, String? date}) async {
    final response = await _dio.get('/attendance/',
        queryParameters: {'group_id': groupId, 'date': date});
    return response.data;
  }

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) async {
    final response = await _dio.post('/attendance/', data: data);
    return response.data;
  }

  Future<List<dynamic>> getGrades({String? studentId}) async {
    final response = await _dio.get('/grades/',
        queryParameters: {'student_id': studentId});
    return response.data;
  }

  Future<Map<String, dynamic>> createGrade(Map<String, dynamic> data) async {
    final response = await _dio.post('/grades/', data: data);
    return response.data;
  }

  Future<List<dynamic>> getInvoices({String? studentId}) async {
    final response = await _dio.get('/invoices/',
        queryParameters: {'student_id': studentId});
    return response.data;
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final response = await _dio.post('/invoices/', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> toggleInvoicePaid(String id, bool paid,
      {String? paymentDate}) async {
    final response = await _dio.patch('/invoices/$id',
        data: {'paid': paid, 'payment_date': paymentDate});
    return response.data;
  }

  Future<Map<String, dynamic>> getGradeStats() async {
    final response = await _dio.get('/grades/stats');
    return response.data;
  }

  Future<Map<String, dynamic>> getAttendanceStats({String? date}) async {
    final response = await _dio.get('/attendance/stats',
        queryParameters: {'date': date});
    return response.data;
  }

  Future<Map<String, dynamic>> getInvoiceStats() async {
    final response = await _dio.get('/invoices/stats');
    return response.data;
  }

  Future<int> getStudentCount() async {
    final response = await _dio.get('/students/count');
    return response.data['count'];
  }

  Future<Map<String, dynamic>> analyzeStudent({
    required String studentId,
    required String subject,
    required List<Map<String, dynamic>> grades,
  }) async {
    final response = await _dio.post('/students/analyze', data: {
      'student_id': studentId,
      'subject': subject,
      'grades': grades,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> generateQR(String teacherId) async {
    final response = await _dio.get('/qr/generate/$teacherId');
    return response.data;
  }

  Future<Map<String, dynamic>> getStudentPinStatus(String studentId) async {
    final response = await _dio.get('/students/$studentId/pin');
    return response.data;
  }

  Future<Map<String, dynamic>> resetStudentPin(String studentId, String newPin) async {
    final response = await _dio.patch('/students/$studentId/pin', data: {
      'pin': newPin,
    });
    return response.data;
  }

  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      final response = await _dio.get('/subscriptions/my');
      return response.data;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> activateCode(String code) async {
    final response = await _dio.post('/subscriptions/activate', data: {
      'code': code,
    });
    return response.data;
  }

  Future<List<dynamic>> getPlans() async {
    final response = await _dio.get('/subscriptions/plans');
    return response.data;
  }

  Future<Map<String, dynamic>> checkVersion(String platform) async {
    final response = await _dio.get('/versions/$platform');
    return response.data;
  }
}
