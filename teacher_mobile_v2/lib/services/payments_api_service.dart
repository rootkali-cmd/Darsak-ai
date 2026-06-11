import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class PaymentsApiService {
  static final PaymentsApiService _instance = PaymentsApiService._internal();
  factory PaymentsApiService() => _instance;
  PaymentsApiService._internal();

  final ApiService _api = ApiService();

  Future<Map<String, dynamic>> getPaymentConfig() async {
    final res = await _api.dio.get('/payments/config');
    if (res.data is Map<String, dynamic>) return res.data;
    return {'data': res.data};
  }

  Future<Map<String, dynamic>> getInstaPayConfig() async {
    final res = await _api.dio.get('/instapay-config');
    if (res.data is Map<String, dynamic>) return res.data;
    return {'data': res.data};
  }

  Future<Map<String, dynamic>> submitPaymentRequest({
    required String teacherId,
    required String planId,
    required String paymentMethod,
    required double amount,
    String? screenshotUrl,
    File? screenshotFile,
    String? phoneNumber,
    String? instapayId,
  }) async {
    if (screenshotFile != null) {
      final fileName = screenshotFile.path.split('/').last;
      final map = {
        'teacher_id': teacherId,
        'plan_id': planId,
        'payment_method': paymentMethod,
        'amount': amount,
        'screenshot': await MultipartFile.fromFile(
          screenshotFile.path,
          filename: fileName,
        ),
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
        if (instapayId != null && instapayId.isNotEmpty) 'instapay_id': instapayId,
      };
      final formData = FormData.fromMap(map);
      final res = await _api.dio.post('/payments/request', data: formData);
      if (res.data is Map<String, dynamic>) return res.data;
      return {'data': res.data};
    } else {
      final data = {
        'teacher_id': teacherId,
        'plan_id': planId,
        'payment_method': paymentMethod,
        'amount': amount,
        if (screenshotUrl != null) 'screenshot_url': screenshotUrl as Object,
        if (phoneNumber != null && phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
        if (instapayId != null && instapayId.isNotEmpty) 'instapay_id': instapayId,
      };
      final res = await _api.dio.post('/payments/request', data: data);
      if (res.data is Map<String, dynamic>) return res.data;
      return {'data': res.data};
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus(String teacherId) async {
    final res = await _api.dio.get('/payments/$teacherId/status');
    if (res.data is Map<String, dynamic>) return res.data;
    return {'data': res.data};
  }
}
