import 'dart:io';
import 'package:dio/dio.dart';
import 'api_service.dart';

class VideoUploadService {
  static const _allowedVideoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp', 'mpeg', 'mpg'};
  static const _maxVideoSize = 2 * 1024 * 1024 * 1024; // 2GB

  static Future<Map<String, dynamic>> setupChannel() async {
    final api = ApiService();
    final resp = await api.dio.post('/lessons/setup-channel');
    final data = resp.data;
    return data is Map ? data as Map<String, dynamic> : {};
  }

  static String? validateFile(String filePath, {bool isVideo = true}) {
    final ext = filePath.split('.').last.toLowerCase();
    if (isVideo) {
      if (!_allowedVideoExts.contains(ext)) {
        return 'الملف غير مدعوم. الصيغ المسموحة: ${_allowedVideoExts.join(", ")}';
      }
    } else {
      if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(ext)) {
        return 'يرجى اختيار ملف صورة فقط (JPG, PNG, WEBP)';
      }
    }
    if (File(filePath).lengthSync() > _maxVideoSize) {
      return 'حجم الملف كبير جداً (الحد الأقصى 2GB)';
    }
    return null;
  }

  static Future<Map<String, dynamic>> uploadVideo({
    required String lessonId,
    required String filePath,
    required String filename,
    String caption = '',
    void Function(double progress)? onProgress,
  }) async {
    final error = validateFile(filePath, isVideo: true);
    if (error != null) throw Exception(error);

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
