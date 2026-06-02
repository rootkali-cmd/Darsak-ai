import 'package:dio/dio.dart';
import 'api_service.dart';

class VideoUploadService {
  static Future<Map<String, dynamic>> setupChannel() async {
    final api = ApiService();
    final resp = await api.dio.post('/lessons/setup-channel');
    final data = resp.data;
    return data is Map ? data as Map<String, dynamic> : {};
  }

  static Future<Map<String, dynamic>> uploadVideo({
    required String lessonId,
    required String filePath,
    required String filename,
    String caption = '',
    void Function(double progress)? onProgress,
  }) async {
    final api = ApiService();
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: filename),
      'caption': caption,
    });

    final resp = await api.dio.post(
      '/lessons/$lessonId/upload-video',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 30),
      ),
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) {
          onProgress(sent / total);
        }
      },
    );

    final data = resp.data;
    return data is Map ? data as Map<String, dynamic> : {};
  }
}
