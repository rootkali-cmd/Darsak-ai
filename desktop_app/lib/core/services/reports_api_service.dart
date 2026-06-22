import '../api/api_client.dart';

final class ReportsApiService {
  final ApiClient _client;

  ReportsApiService(this._client);

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

    return _client.get(
      '/reports/students/$teacherId',
      queryParameters: query.isNotEmpty ? query : null,
    );
  }

  Future<Map<String, dynamic>> getAnalyticsSummary(String teacherId) async {
    return _client.get('/reports/analytics/$teacherId');
  }
}
