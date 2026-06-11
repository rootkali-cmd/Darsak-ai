import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportsApiService {
  static final ReportsApiService _instance = ReportsApiService._internal();
  factory ReportsApiService() => _instance;

  late final Dio _dio;
  static const _baseUrl = 'https://darsak-backend.fly.dev/api';

  ReportsApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
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

  Future<Map<String, dynamic>> getStudentReports(
    String teacherId, {
    String? subject,
    String? dateFrom,
    String? dateTo,
  }) async {
    final query = <String, dynamic>{};
    if (subject != null && subject.isNotEmpty) query['subject'] = subject;
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;

    final res = await _dio.get(
      '/reports/students/$teacherId',
      queryParameters: query,
    );
    return res.data is Map<String, dynamic> ? res.data : {'data': res.data};
  }

  Future<Map<String, dynamic>> getAnalyticsSummary(String teacherId) async {
    final res = await _dio.get('/reports/analytics/$teacherId');
    return res.data is Map<String, dynamic> ? res.data : {'data': res.data};
  }
}
