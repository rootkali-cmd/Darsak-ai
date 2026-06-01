import 'dart:convert';
import 'package:dio/dio.dart';
import 'api_service.dart';

class VideoUploadService {
  static Future<Map<String, dynamic>?> checkOrCreateChannel() async {
    try {
      final api = ApiService();
      final response = await api.dio.post('/lessons/setup-channel/');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
    } on DioException catch (e) {
      final msg = _extractError(e);
      throw Exception(msg);
    }
    return null;
  }

  static Future<Map<String, dynamic>> uploadVideo({
    required String lessonId,
    required String filePath,
    required String filename,
    String caption = '',
    void Function(int sent, int total)? onProgress,
  }) async {
    try {
      final api = ApiService();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
        'caption': caption,
      });

      final response = await api.dio.post(
        '/lessons/$lessonId/upload-video/',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
        onSendProgress: onProgress,
      );
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) return Map<String, dynamic>.from(data);
      }
      throw Exception('Upload returned unexpected response');
    } on DioException catch (e) {
      final msg = _extractError(e);
      throw Exception(msg);
    }
  }

  static String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      return data['detail']?.toString() ?? 'Upload failed';
    }
    return e.message ?? 'Upload failed';
  }
}
