import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'constants.dart';

class ApiService {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiService() {
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
    final response = await _dio.get('/versions/mobile');
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
}
