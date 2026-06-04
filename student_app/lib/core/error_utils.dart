import 'package:dio/dio.dart';

String getDioErrorMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
      return 'أنت غير متصل بالإنترنت';
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'تعذر الاتصال. تأكد من الإنترنت';
    default:
      final statusCode = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      if (statusCode != null) {
        return 'خطأ $statusCode';
      }
      return e.message ?? 'حدث خطأ غير معروف';
  }
}
