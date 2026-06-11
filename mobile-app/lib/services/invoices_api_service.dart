import '../core/api_service.dart';

class InvoicesApiService {
  static final InvoicesApiService _instance = InvoicesApiService._internal();
  factory InvoicesApiService() => _instance;
  InvoicesApiService._internal();

  final ApiService _api = ApiService();

  Future<List<dynamic>> getMyInvoices() async {
    final response = await _api.dio.get('/invoices/my');
    return response.data is List ? response.data as List : [];
  }

  Future<Map<String, dynamic>> createInvoice({
    required String lessonId,
    required double amount,
    required String paymentMethod,
  }) async {
    final response = await _api.dio.post('/invoices/create', data: {
      'lesson_id': lessonId,
      'amount': amount,
      'payment_method': paymentMethod,
    });
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<Map<String, dynamic>> uploadPaymentProof({
    required String invoiceId,
    required String screenshotUrl,
  }) async {
    final response = await _api.dio.post('/invoices/upload-proof', data: {
      'invoice_id': invoiceId,
      'screenshot_url': screenshotUrl,
    });
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<List<dynamic>> getTeacherLessons() async {
    final response = await _api.dio.get('/lessons/my-teacher');
    return response.data is List ? response.data as List : [];
  }
}
