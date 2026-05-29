import 'package:dio/dio.dart';
import 'api_client.dart';
import '../utils/constants.dart';

final class ApiService {
  final ApiClient _client;
  /// Bare Dio without interceptors for ping/health checks
  late final Dio _bareDio;

  ApiService(this._client) {
    _bareDio = Dio(BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
  }

  // ─── Auth ───
  Future<Map<String, dynamic>> login(String email, String password) =>
      _client.post('/auth/login', data: {'email': email, 'password': password});

  Future<Map<String, dynamic>> getMe() => _client.get('/auth/me');

  Future<Map<String, dynamic>> saveOnboarding({
    required String fullName,
    required List<String> subjects,
    required List<String> levels,
  }) =>
      _client.patch('/auth/onboarding', data: {
        'full_name': fullName,
        'subjects': subjects,
        'levels': levels,
      });

  // ─── Students ───
  Future<List<dynamic>> getStudents({String? search}) =>
      _client.getList('/students/', queryParameters: {'search': search});

  Future<Map<String, dynamic>> getStudent(String id) => _client.get('/students/$id');

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) =>
      _client.post('/students/', data: data);

  Future<void> deleteStudent(String studentId) => _client.delete('/students/$studentId');

  Future<void> deleteGroup(String groupId) => _client.delete('/groups/$groupId');

  Future<Map<String, dynamic>> analyzeStudent({
    required String studentId,
    required String subject,
    required List<Map<String, dynamic>> grades,
  }) =>
      _client.post('/students/analyze', data: {
        'student_id': studentId,
        'subject': subject,
        'grades': grades,
      });

  Future<Map<String, dynamic>> getStudentPinStatus(String studentId) =>
      _client.get('/students/$studentId/pin');

  Future<Map<String, dynamic>> resetStudentPin(String studentId, String newPin) =>
      _client.patch('/students/$studentId/pin', data: {'pin': newPin});

  // ─── Groups ───
  Future<List<dynamic>> getGroups() => _client.getList('/groups/');

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) =>
      _client.post('/groups/', data: data);

  // ─── Attendance ───
  Future<List<dynamic>> getAttendance({String? groupId, String? date}) =>
      _client.getList('/attendance/', queryParameters: {'group_id': groupId, 'date': date});

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) =>
      _client.post('/attendance/', data: data);

  Future<Map<String, dynamic>> getAttendanceStats({String? date}) =>
      _client.get('/attendance/stats', queryParameters: {'date': date});

  // ─── Grades ───
  Future<List<dynamic>> getGrades({String? studentId}) =>
      _client.getList('/grades/', queryParameters: {'student_id': studentId});

  Future<Map<String, dynamic>> createGrade(Map<String, dynamic> data) =>
      _client.post('/grades/', data: data);

  Future<Map<String, dynamic>> getGradeStats() => _client.get('/grades/stats');

  // ─── Invoices ───
  Future<List<dynamic>> getInvoices({String? studentId}) =>
      _client.getList('/invoices/', queryParameters: {'student_id': studentId});

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) =>
      _client.post('/invoices/', data: data);

  Future<Map<String, dynamic>> toggleInvoicePaid(String id, bool paid,
          {String? paymentDate}) =>
      _client.patch('/invoices/$id', data: {'paid': paid, 'payment_date': paymentDate});

  Future<Map<String, dynamic>> getInvoiceStats() => _client.get('/invoices/stats');

  // ─── QR ───
  Future<Map<String, dynamic>> generateQR(String teacherId) =>
      _client.get('/qr/generate/$teacherId');

  // ─── Exams ───
  Future<List<dynamic>> getExams() => _client.getList('/exams');

  Future<Map<String, dynamic>> createExam(String title, int durationMinutes,
          {String? description, int? totalQuestions, int? essayQuestions}) =>
      _client.post('/exams', data: {
        'title': title,
        'duration_minutes': durationMinutes,
        if (description != null) 'description': description,
        if (totalQuestions != null) 'total_questions': totalQuestions,
        if (essayQuestions != null) 'essay_questions': essayQuestions,
      });

  Future<Map<String, dynamic>> getExam(String examId) => _client.get('/exams/$examId');

  Future<Map<String, dynamic>> updateExam(String examId, Map<String, dynamic> data) =>
      _client.put('/exams/$examId', data: data);

  Future<void> deleteExam(String examId) => _client.delete('/exams/$examId');

  Future<Map<String, dynamic>> publishExam(String examId) =>
      _client.post('/exams/$examId/publish');

  Future<List<dynamic>> getExamQuestions(String examId) =>
      _client.getList('/exams/$examId/questions');

  Future<Map<String, dynamic>> addQuestion(String examId, Map<String, dynamic> data) =>
      _client.post('/exams/$examId/questions', data: data);

  Future<Map<String, dynamic>> updateQuestion(
          String examId, String questionId, Map<String, dynamic> data) =>
      _client.put('/exams/$examId/questions/$questionId', data: data);

  Future<void> deleteQuestion(String examId, String questionId) =>
      _client.delete('/exams/$examId/questions/$questionId');

  Future<Map<String, dynamic>> aiGenerateExam(String title, String filePath,
          {String? subject, int durationMinutes = 30}) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      'title': title,
      if (subject != null) 'subject': subject,
      'duration_minutes': durationMinutes,
    });
    return _client.uploadFile('/exams/ai-generate', formData);
  }

  Future<List<dynamic>> getExamResults(String examId) =>
      _client.getList('/exams/$examId/results');

  Future<Map<String, dynamic>> analyzeStudentExam(String studentExamId) =>
      _client.post('/exams/analyze/$studentExamId');

  // ─── Subscriptions ───
  Future<Map<String, dynamic>?> getMySubscription() async {
    try {
      return await _client.get('/subscriptions/my');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> activateCode(String code) =>
      _client.post('/subscriptions/activate', data: {'code': code});

  Future<List<dynamic>> getPlans() => _client.getList('/subscriptions/plans');

  // ─── Versions / Updates ───
  Future<Map<String, dynamic>> checkVersion(String platform,
          {String? channel}) async {
    final response = await _client.dio
        .get('/versions/$platform', queryParameters: {'channel': channel});
    return response.data;
  }

  // ─── Analytics ───
  Future<void> sendAnalyticsEvent(Map<String, dynamic> data) async {
    try {
      await _client.post('/analytics/event', data: data);
    } catch (_) {}
  }

  // ─── Health ───
  /// Lightweight server reachability check using a bare Dio instance
  /// (no auth interceptors) so a bad token cannot trigger logout.
  Future<bool> ping() async {
    try {
      await _bareDio.get('/config/client');
      return true;
    } on DioException catch (e) {
      // Any HTTP response means server is up; only network-level failures matter
      if (e.response != null) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Remote Config ───
  Future<Map<String, dynamic>?> getRemoteConfig() async {
    try {
      return await _client.get('/config/client');
    } catch (_) {
      return null;
    }
  }
}
