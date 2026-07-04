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
      _client.getList('/students/', queryParameters: {'search': search, 'limit': 500});

  Future<Map<String, dynamic>> getStudent(String id) => _client.get('/students/$id');

  Future<Map<String, dynamic>> createStudent(Map<String, dynamic> data) =>
      _client.post('/students/', data: data);

  Future<Map<String, dynamic>> updateStudent(String studentId, Map<String, dynamic> data) =>
      _client.put('/students/$studentId', data: data);

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

  Future<Map<String, dynamic>> updateGroup(String groupId, Map<String, dynamic> data) =>
      _client.put('/groups/$groupId', data: data);

  // ─── Attendance ───
  Future<List<dynamic>> getAttendance({String? groupId, String? date}) =>
      _client.getList('/attendance/', queryParameters: {'group_id': groupId, 'date': date});

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) =>
      _client.post('/attendance/', data: data);

  /// Mark attendance via QR scan. Returns student info on success.
  Future<Map<String, dynamic>> markAttendanceByQr(String qrData, {String? groupId}) =>
      _client.post('/attendance/qr/', data: {
        'qr_data': qrData,
        if (groupId != null) 'group_id': groupId,
      });

  Future<Map<String, dynamic>> getAttendanceStats({String? date}) =>
      _client.get('/attendance/stats', queryParameters: {'date': date});

  // ─── Grades ───
  Future<List<dynamic>> getGrades({String? studentId}) =>
      _client.getList('/grades/', queryParameters: {'student_id': studentId, 'limit': 500});

  Future<Map<String, dynamic>> createGrade(Map<String, dynamic> data) =>
      _client.post('/grades/', data: data);

  Future<Map<String, dynamic>> updateGrade(String gradeId, Map<String, dynamic> data) =>
      _client.put('/grades/$gradeId', data: data);

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

  // ─── Teacher Invoices ───
  Future<List<dynamic>> getTeacherInvoices() =>
      _client.getList('/invoices/teacher');

  Future<Map<String, dynamic>> teacherCreateInvoice(Map<String, dynamic> data) =>
      _client.post('/invoices/teacher-create', data: data);

  Future<Map<String, dynamic>> approveInvoice(String id) =>
      _client.post('/invoices/$id/approve');

  Future<Map<String, dynamic>> rejectInvoice(String id) =>
      _client.post('/invoices/$id/reject');

  // ─── QR ───
  Future<Map<String, dynamic>> generateQR(String teacherId) =>
      _client.get('/qr/generate/$teacherId');

  // ─── Exams ───
  Future<List<dynamic>> getExams() => _client.getList('/exams', queryParameters: {'limit': 200});

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

  // ─── Online Students ───
  Future<List<dynamic>> getOnlineStudents() =>
      _client.getList('/students/type/online');

  // ─── Student Approval ───
  Future<Map<String, dynamic>> approveStudent(String id) =>
      _client.patch('/students/$id/approve');

  Future<Map<String, dynamic>> rejectStudent(String id, {String? reason}) =>
      _client.patch('/students/$id/reject', data: {if (reason != null) 'reason': reason});

  // ─── Teacher Contacts ───
  Future<List<dynamic>> getTeacherContacts() =>
      _client.getList('/teacher/contacts/');

  Future<Map<String, dynamic>> addTeacherContact(Map<String, dynamic> data) =>
      _client.post('/teacher/contacts/', data: data);

  Future<void> deleteTeacherContact(String id) =>
      _client.delete('/teacher/contacts/$id');

  // ─── Profile ───
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) =>
      _client.put('/auth/me', data: data);

  // ─── Reports ───
  Future<List<dynamic>> getStudentReports({
    String? teacherId,
    String? subject,
    String? dateFrom,
    String? dateTo,
  }) =>
      _client.getList('/reports', queryParameters: {
        if (teacherId != null) 'teacher_id': teacherId,
        if (subject != null) 'subject': subject,
        if (dateFrom != null) 'date_from': dateFrom,
        if (dateTo != null) 'date_to': dateTo,
      });

  // ─── Remote Config ───
  Future<Map<String, dynamic>?> getRemoteConfig() async {
    try {
      return await _client.get('/config/client');
    } catch (_) {
      return null;
    }
  }

  // ─── Generic pass-through ───
  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _client.get(path, queryParameters: queryParameters);

  Future<Map<String, dynamic>> post(String path, {dynamic data}) =>
      _client.post(path, data: data);

  Future<Map<String, dynamic>> patch(String path, {dynamic data}) =>
      _client.patch(path, data: data);

  Future<Map<String, dynamic>> put(String path, {dynamic data}) =>
      _client.put(path, data: data);

  Future<void> delete(String path) =>
      _client.delete(path);

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? queryParameters}) =>
      _client.getList(path, queryParameters: queryParameters);

  // ── Wallet ──
  Future<Map<String, dynamic>> getWallet() => _client.get('/wallet');
  Future<Map<String, dynamic>> requestPayout(double amount, String method, String phone) =>
      _client.post('/wallet/payout-request', data: {'amount': amount, 'payout_method': method, 'payout_phone': phone});
  Future<Map<String, dynamic>> getPayoutRequests({int limit = 50, int offset = 0}) =>
      _client.get('/wallet/payout-requests', queryParameters: {'limit': limit, 'offset': offset});
  Future<Map<String, dynamic>> getWalletTransactions({int limit = 50, int offset = 0}) =>
      _client.get('/wallet/transactions', queryParameters: {'limit': limit, 'offset': offset});

  // ── Admission ──
  Future<Map<String, dynamic>> getPendingAdmissions({int limit = 50, int offset = 0}) =>
      _client.get('/admission/pending', queryParameters: {'limit': limit, 'offset': offset});
  Future<Map<String, dynamic>> approveAdmission(String admissionId) =>
      _client.post('/admission/$admissionId/approve');
  Future<Map<String, dynamic>> rejectAdmission(String admissionId, {String? reason}) =>
      _client.post('/admission/$admissionId/reject', data: {'reason': reason ?? ''});

  // ── Courses ──
  Future<Map<String, dynamic>> getCourses() => _client.get('/courses');
  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) => _client.post('/courses', data: data);
  Future<Map<String, dynamic>> getCourse(String id) => _client.get('/courses/$id');
  Future<Map<String, dynamic>> updateCourse(String id, Map<String, dynamic> data) => _client.put('/courses/$id', data: data);
  Future<void> deleteCourse(String id) => _client.delete('/courses/$id/delete');
  Future<Map<String, dynamic>> updateCoursePricing(String id, Map<String, dynamic> data) => _client.put('/courses/$id/pricing', data: data);

  // Chapters
  Future<Map<String, dynamic>> createChapter(String courseId, Map<String, dynamic> data) => _client.post('/courses/$courseId/chapters', data: data);
  Future<Map<String, dynamic>> getChapters(String courseId) => _client.get('/courses/$courseId/chapters');
  Future<void> deleteChapter(String chapterId) => _client.delete('/courses/chapters/$chapterId/delete');

  // Lessons
  Future<Map<String, dynamic>> createLesson(String chapterId, Map<String, dynamic> data) => _client.post('/courses/chapters/$chapterId/lessons', data: data);
  Future<Map<String, dynamic>> getLessons(String chapterId) => _client.get('/courses/chapters/$chapterId/lessons');
  Future<Map<String, dynamic>> getLesson(String lessonId) => _client.get('/courses/lessons/$lessonId');
  Future<Map<String, dynamic>> updateLesson(String lessonId, Map<String, dynamic> data) => _client.put('/courses/lessons/$lessonId', data: data);
  Future<void> deleteLesson(String lessonId) => _client.delete('/courses/lessons/$lessonId/delete');

  // Course Cover Image Upload
  Future<Map<String, dynamic>> uploadCourseCover(String courseId, String filePath) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    return _client.uploadFile('/courses/$courseId/cover', formData);
  }

  // Lesson Video Upload
  Future<Map<String, dynamic>> uploadLessonVideo(String lessonId, String filePath) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    return _client.uploadFile('/courses/lessons/$lessonId/video', formData);
  }

  // Lesson File Upload
  Future<Map<String, dynamic>> uploadLessonFile(String lessonId, String filePath) async {
    final formData = FormData.fromMap({'file': await MultipartFile.fromFile(filePath)});
    return _client.uploadFile('/courses/lessons/$lessonId/files', formData);
  }

  // Lesson File Delete
  Future<void> deleteLessonFile(String lessonId, String fileId) =>
      _client.delete('/courses/lessons/$lessonId/files/$fileId');

  Future<Map<String, dynamic>?> getPaymentConfig() async {
    try {
      final res = await _client.dio.get('/payments/config');
      return res.data is Map ? res.data : null;
    } catch (_) {
      try {
        final res = await _client.dio.get('/students/me/payment-config');
        return res.data is Map ? res.data : null;
      } catch (_) {
        return null;
      }
    }
  }
}
