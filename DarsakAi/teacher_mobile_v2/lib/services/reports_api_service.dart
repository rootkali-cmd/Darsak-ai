import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class ReportsApiService {
  static final ReportsApiService _instance = ReportsApiService._internal();
  factory ReportsApiService() => _instance;

  late final Dio _dio;

  ReportsApiService._internal() {
    _dio = ApiService().dio;
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
